# Function Interact Action

![GitHub release (latest by date)](https://img.shields.io/github/v/release/TrueSelph/function_interact_action)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/TrueSelph/function_interact_action/test-function_interact_action.yaml)
![GitHub issues](https://img.shields.io/github/issues/TrueSelph/function_interact_action)
![GitHub pull requests](https://img.shields.io/github/issues-pr/TrueSelph/function_interact_action)
![GitHub](https://img.shields.io/github/license/TrueSelph/function_interact_action)

The **Function Interact Action** is designed to determine the most appropriate action(s) (intents) to execute while extracting relevant parameters from user inputs. Alternatively it can be used in non-strict mode which allows it to perform extractions without strict routing to matched actions. It serves as a critical component within conversational flows, enabling precise intent detection, action selection, and context-aware parameter extraction.

## Package Information

- **Name:** `jivas/function_interact_action`
- **Author:** [V75 Inc.](https://v75inc.com/)
- **Architype:** `FunctionInteractAction`

## Meta Information

- **Title:** Function Interact Action
- **Description:** Chooses the optimal action(s) while extracting relevant parameters based on user utterances and context.
- **Group:** core
- **Type:** interact_action

## Configuration

The default configuration for this action is highly customizable:

- **chained** (`bool`, default=`False`):
  If set to `true`, the action executes only when one or more of its registered actions have already been queued by a preceding Intent Interact Action.

- **strict** (`bool`, default=`True`):
  Enforces strict mode execution. If enabled, it executes only those actions belonging to explicitly matched functions.

- **exceptions** (`list`, default=`['PersonaInteractAction']`):
  Defines actions that should always execute irrespective of intent matching when in strict mode. Users may extend this exception list:
  ```yaml
  exceptions:
    - PersonaInteractAction
    - CustomAlwaysExecuteAction
  ```

## Dependencies

- **Jivas:** `^2.0.0`
- **Actions:**
  - [`jivas/langchain_model_action`](https://github.com/jivas/langchain_model_action): `^0.0.1`

---

## How To Configure

This section details the process and parameters for configuring the Function Interact Action to suit your requirements.

### 1. Basic Configuration

The default configurable options to control action execution behavior:

```yaml
chained: false                    # if chained, only executes when one of its actions added by the intent interact action is queued.
strict: true                      # if strict, only actions belonging to matched functions will be executed.
timezone: "America/Guyana"        # The timezone to be used for the datetime placeholder
exceptions:                       # list of actions which are included in intent, regardless
  - PersonaInteractAction
```

Consider your interaction workflows when adjusting these parameters. For broader interaction scope, disable strict enforcement or add relevant exceptions.

### 2. Language Model Configuration

The Function Interact Action uses a language model and conversational context to infer intents and parameter extraction accurately. Adjust these settings to tune model behavior and accuracy:

```yaml
history_size: 5                   # Number of recent conversations considered
max_statement_length: 500         # Maximum input text length for processing
model_action: LangChainModelAction # Language model action to use
model_name: gpt-4o                # Model identifier used for inference
model_temperature: 0.2            # Model randomness (low value: more deterministic)
model_max_tokens: 2048            # Maximum tokens allowed in model responses
```

Modify the parameters to balance performance, resource utilization, and predictive accuracy needs.

### 3. Functions and Parameter Extraction

The Function Interact Action interacts with various actions through defined functions which specify desired intents and associated parameters to extract. Utilize placeholders to handle dynamic data points such as datetime references or custom contextual values.

**Example configuration:**

```yaml
functions:
  - type: function
    function:
      name: "extract_user_details"
      description: >
        Extracted information about user's personal details, <custom_placeholder>, request for a specific service or scheduling preferences.
        Use the current date <datetime> to determine the date or time the user references.
        Extract any information concerning the user wanting to bring in a machine or vehicle.
      parameters:
        type: object
        properties:
          description_of_issue:
            type: string
            description: "Any details concerning the user wanting to bring in a machine or vehicle."
          first_name:
            type: string
            description: "Returns the first name of the user."
          last_name:
            type: string
            description: "Returns the last name of the user."
        required:
          - description_of_issue
    placeholders:
      custom_placeholder: "custom_placeholder_value"

  - type: function
    function:
      name: "extract_confirmation_choice"
      description: >
        Determine if the user confirms the provided draft report for posting or cancels. Handles affirmatives (e.g., 'yes', 'post it', 'send now', 'sure') and negatives (e.g., 'no', 'cancel', 'nevermind', 'nah').
      parameters:
        type: object
        properties:
          confirmation_choice:
            type: string
            enum: ["true", "false"]
            description: >
              Returns 'true' if the user responds affirmatively (e.g., 'yes', 'ok'). Returns 'false' for negatives (e.g., 'no', 'cancel', 'nah', 'nevermind').
        required:
          - confirmation_choice
```

### Using Placeholders

**Placeholders** are useful for providing dynamic context-sensitive information during extraction:

- `<datetime>` placeholders are automatically injected with the current timestamp.
- Custom placeholders can also be added within function descriptions and replaced accordingly, e.g.:

```yaml
placeholders:
  custom_placeholder: "current customer support context"
```

This approach ensures accurate, contextual parameter extraction particularly around time-sensitive and context-varying information.

---

### Example Complete YAML Configuration

A complete example configuration looks as follows:

```yaml
function_interact_action:
  chained: false
  strict: true
  exceptions:
    - PersonaInteractAction
    - AlwaysExecuteCustomAction

  history_size: 5
  max_statement_length: 500
  model_action: LangChainModelAction
  model_name: gpt-4o
  model_temperature: 0.2
  model_max_tokens: 2048

  functions:
    - type: function
      function:
        name: "extract_user_details"
        description: "Extracted information about user's personal details, <custom_placeholder>, request for a specific service or scheduling preferences. Use the current date <datetime> for parsing date or time references. Extract information concerning the user wanting to bring in a machine or vehicle."
        parameters:
          type: object
          properties:
            description_of_issue:
              type: string
              description: "Details on user's vehicle or machine issue."
            first_name:
              type: string
              description: "The user's first name."
            last_name:
              type: string
              description: "The user's last name."
          required:
            - description_of_issue
      placeholders:
        custom_placeholder: "scheduled service inquiry"

    - type: function
      function:
        name: "extract_confirmation_choice"
        description: "Determine user's confirmation or cancellation of provided draft report (Affirmatives: 'yes', 'ok', 'post it'; Negatives: 'no', 'cancel', 'nah')."
        parameters:
          type: object
          properties:
            confirmation_choice:
              type: string
              enum: ["true", "false"]
              description: "'true' for affirmatives, 'false' for negatives."
          required:
            - confirmation_choice
```

---

### 🌟 Best Practices

- Clearly define each intent function and provide meaningful context in descriptions.
- Regularly review and adjust placeholder values for accurate and context-aware extraction.
- Test your function and placeholder configurations thoroughly in staging.

---

## 🔰 Contributing

- **🐛 [Report Issues](https://github.com/TrueSelph/function_interact_action/issues)**: Submit identified bugs or suggest improvements.
- **💡 [Submit Pull Requests](https://github.com/TrueSelph/function_interact_action/blob/main/CONTRIBUTING.md)**: Contribute enhancements directly.

## 🎗 License

This project is licensed under the Apache License 2.0. Refer to [LICENSE](../LICENSE) for further details.