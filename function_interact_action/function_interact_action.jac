import:py json;
import:py logging;
import:py traceback;
import:py from typing { Union }
import:py from logging { Logger }
import:py from jivas.agent.modules.agentlib.utils { Utils }
import:jac from jivas.agent.action.actions { Actions }
import:jac from jivas.agent.action.interact_action { InteractAction }
import:jac from jivas.agent.action.interact_graph_walker { interact_graph_walker }


node FunctionInteractAction :InteractAction: {
    # based on an utterance, classifies agaisnt registered intents

    # set up logger
    static has logger:Logger = logging.getLogger(__name__);

    has strict:bool = False; # if strict, only actions belonging to matched functions will be executed.
    has chained:bool = False; # if chained, only executes when one of its actions added by the Function Interact Action is queued.
    has history:bool = False; # utilize history when running functions
    has history_size:int = 3; # the number of interactions in conversational history to use
    has max_statement_length:int = 500;
    has timezone:str = "America/Guyana";
    has model_action:str = "LangChainModelAction";
    has model_name:str = "gpt-4o-mini";
    has model_temperature:float = 0.2;
    has model_max_tokens:int = 4096;
    has exceptions:list = [];


    can touch(visitor: interact_graph_walker) -> bool {
        # authorize the interact to run

        if(self.chained and self.get_agent().get_actions().get(action_label="IntentInteractAction")) {
            function_index = self.get_function_index(visitor);
            for intent in visitor.interaction_node.get_intents() {
                if intent in function_index.keys() and visitor.utterance {
                    return True;
                }
            }
        } elif visitor.utterance {
            return True;
        }
    }

    can execute(visitor: interact_graph_walker) -> dict {

        # load up all functions by interact actions
        function_index = self.get_function_index(visitor);
        # get a consolidated list of functions for chat completions
        functions = [item for sublist in function_index.values() for item in sublist];

        if(function_index) {

            tools = self.process_functions(visitor, functions);

            for tool in tools {
                # remap the resulting function to the action it came from
                action_label = self.get_action_by_function(index = function_index, function_name = tool.get('name', None));
                visitor.interaction_node.add_function(action_label = action_label, function = tool);
            }

        }

        return visitor.export();
    }

    can process_functions(visitor: interact_graph_walker, functions:list, kwargs:dict = {}) -> list {

        # Process keyword arguments to configure function behavior with fallback to defaults
        history = kwargs.get("history", self.history);
        history_size = kwargs.get("history_size", self.history_size);
        max_statement_length = kwargs.get("max_statement_length", self.max_statement_length);
        model_action = kwargs.get("model_action", self.model_action);
        model_name = kwargs.get("model_name", self.model_name);
        model_temperature = kwargs.get("model_temperature", self.model_temperature);
        model_max_tokens = kwargs.get("model_max_tokens", self.model_max_tokens);

        prompt_messages = [];
        if (history) {
            # grab the history
            statements = visitor.frame_node.get_transcript_statements(interactions = history_size, max_statement_length = max_statement_length);

            if (statements) {
                prompt_messages.extend(statements);
                self.logger.debug(f"history: {json.dumps(statements)}");
            }

            # prompt_messages.extend([{"human": visitor.utterance}]);
        } else {
            # here we cater to whether we have context information or not..
            prompt_messages = [
                {"human": visitor.utterance}
            ];
        }

        if(model_action := self.get_agent().get_actions().get(action_label=model_action)) {

            if (model_action_result := model_action.call_model(
                prompt_messages = prompt_messages,
                prompt_variables = {},
                kwargs = {
                    "functions": functions,
                    "model_name": model_name,
                    "model_temperature": model_temperature,
                    "model_max_tokens": model_max_tokens
                },
                interaction_node = visitor.interaction_node
            )) {

                if(tools := model_action_result.get_result()) {
                    return tools;
                }
            }
        }

        return [];
    }

    can get_function_index(visitor: interact_graph_walker) -> dict {
        # retrieves a dictionary of anchor statements from each action for classification; to be spawned on an agent
        function_index = {};

        # get a list of all interact actions
        all_actions = self.get_agent().get_actions().get_all(only_interact_actions=True, only_enabled=True);

        for action_node in all_actions {
            # only enabled actions which implement functions are of interest to us
            if(action_node.functions and action_node.label != self.get_type()) {
                functions_copy = action_node.functions.copy();
                for item in functions_copy {
                    if(description := item.get("function", {}).get("description")){
                        # checks for custom placeholders  that should be a dict of placeholder:value pairs
                        if('placeholders' in item['function']){
                            placeholders = item['function']['placeholders'];
                            item['function']['description'] = self.process_placeholders(description, placeholders);
                        # checks for any special timezone for datetime placeholder
                        }elif('timezone' in item['function']){
                            timezone = item['function']['timezone'];
                            item['function']['description'] = self.process_placeholders(description=description, timezone=timezone);
                        }
                        else{
                            item['function']['description'] = self.process_placeholders(description);
                        }

                    }
                }
                function_index[action_node.label] = functions_copy;
            }
        }

        return function_index;
    }

    can process_placeholders(description:str, placeholders:Optional[dict]={}) -> str {
        # process placeholders enlclosed in <> in function descriptions
        current_datetime = Utils.date_now(self.timezone, "%Y-%m-%d %H:%M:%S");
        result_string = description.replace('<datetime>', current_datetime);

        if(placeholders) {
            for (key, value) in placeholders.items() {
                # evaluate the value as a python expression so simple code can be run
                try{
                    exec('global placeholder_value; placeholder_value = %s' % value);
                    result_string = result_string.replace(f'<{key}>', placeholder_value);
                }except Exception as e{
                    result_string = result_string.replace(f'<{key}>', value);
                    self.logger.error(f"An exception occurred in {self.label}:\n{traceback.format_exc()}\n");
                }
            }
        }
        return result_string;
    }

    can get_action_by_function(index:dict, function_name:str) {
        # searches function index and returns action by function name

        for (key, value) in index.items() {
            for function in value {
                if function_name == function.get('function', {}).get('name', None) {
                    return key;
                }
            }
        }

        return None;
    }

    can healthcheck() -> Union[bool, dict] {

        if(not self.model_action) {
            return {
                "status": False,
                "message": "Model action not specified.",
                "severity": "error"
            };
        }

        if(not self.model_name) {
            return {
                "status": False,
                "message": "Model name not specified.",
                "severity": "error"
            };
        }

        model_action = self.get_agent().get_actions().get(action_label=self.model_action);
        if not model_action {
            return {
                "status": False,
                "message": f"Model Action is not registered. {self.model_action}",
                "severity": "error"
            };
        }

        return True;

    }

}
