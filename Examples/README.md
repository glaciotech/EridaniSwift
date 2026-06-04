
## Running the examples

- Open `Examples/EridaniAppExamples.xcodeproj`
- Select a scheme and run:
  - `ChatAppExample`
  - `ToolUsingAgentExample`

## API key / configuration

The example apps choose how to connect based on whether `OPENAI_API_KEY` exists in `UserDefaults`:

- If `OPENAI_API_KEY` **is set**, the apps use a **direct** OpenAI connection.
- If `OPENAI_API_KEY` **is not set**, the apps attempt to use the **Eridani proxy** via `EridaniProxyFactory.createProxiedAIContainer()`. This is primarily used for production, see Option B below.

### Option A (required): Direct mode (set `OPENAI_API_KEY`)

You'll need an OpenAI API key to use the example Apps

The examples read the value from `UserDefaults`:

- `OPENAI_API_KEY`

The easiest way to set this for the examples is in Xcode:

- In Xcode, go to **Product** -> **Scheme** -> **Edit Scheme...**
- Select **Run** -> **Arguments**
- Under **Arguments Passed On Launch**, add:
  - `-OPENAI_API_KEY`
  - `<your_openai_api_key>`

### Option B: Proxy mode (no `OPENAI_API_KEY`)

Using the Eridani proxy requires a proxy app API key:

- `ERIDANI_PROXY_APP_API_KEY`

The Eridani proxy is primarily intended for production releases. If you’re interested in using it (and to obtain an `ERIDANI_PROXY_APP_API_KEY`), contact us at `proxy-inquiry@eridani.tech`.

The easiest way to set this for the examples is in Xcode:

- In Xcode, go to **Product** -> **Scheme** -> **Edit Scheme...**
- Select **Run** -> **Arguments**
- Under **Arguments Passed On Launch**, add:
  - `-ERIDANI_PROXY_APP_API_KEY`
  - `<your_proxy_app_api_key>`

After setting the values, re-run the app.

## Notes

- The ToolUsingAgent example also demonstrates tool approval UX using `ToolExecutionUserApprovalCoordinator`.
- If you change models, use any value from `RemoteLLMModel` / `RemoteLLMModel` as shown in the examples.
