# Smoketest


This suite is designed to perform preliminary checks on your APIs to ensure they are operational and performing as expected. It serves as a diagnostic tool to verify the health of your endpoints.

## Usage Instructions

1. **Environment Setup**:

   - **.env**: Contains your API keys, base paths, and the list of endpoints. You can initialize `.env` by copying from `.default.env` and tweaking values as needed.
   - If `.env` is missing, the script will try to grab `.default.env` from GitHub (if not found locally) and prompt you to update it.

2. **Executing Tests**:

   - Ensure the smoketest script has execute permissions. You can set this by running:
     ```bash
     chmod +x smoketest.sh
     ```
   - Run the smoketest script using the following command:
     ```bash
     ./smoketest.sh
     ```

3. **Reviewing Results**:
   - The test results will be displayed in your terminal. Please review for any errors or warnings that may require attention.

## Configuration Details

- **.default.env / .env**: Holds everything—your environment variables (like `<ENV>_TOKEN_URL`, `<ENV>_CLIENT_ID`, `<ENV>_CLIENT_SECRET`) plus the endpoints to hit. You can easily add or remove APIs to be called.
