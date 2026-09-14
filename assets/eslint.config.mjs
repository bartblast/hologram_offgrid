import js from "@eslint/js";
import globals from "globals";

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: "latest",
      globals: {
        ...globals.browser,
      },
      sourceType: "module",
    },
    rules: {
      "no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],
    },
  },
  {
    // Tool configs such as tailwind.config.js are CommonJS modules run by Node.
    files: ["**/*.js"],
    languageOptions: {
      globals: {
        ...globals.node,
      },
      sourceType: "commonjs",
    },
  },
];
