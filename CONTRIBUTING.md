# Contributing to Twake.AI Kickstart

Thank you for your interest in contributing to Twake.AI Kickstart! This guide will help you get started.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:

- A clear and descriptive title
- Steps to reproduce the problem
- Expected behavior vs. actual behavior
- Your environment (OS, Docker version, Docker Compose version)
- Relevant logs (`docker logs <container_name>`)

### Suggesting Enhancements

Feature requests are welcome. Please open an issue describing:

- The problem you are trying to solve
- Your proposed solution
- Any alternatives you have considered

### Submitting Changes

1. **Fork** the repository and create your branch from `main`:
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make your changes**, following the conventions described below.

3. **Test your changes** by starting the full stack:
   ```bash
   docker network create twake-network --subnet=172.27.0.0/16  # if not already created
   ./wrapper.sh up -d
   ```

4. **Commit your changes** with a clear commit message:
   ```bash
   git commit -m "feat: Add support for custom SMTP relay"
   ```

5. **Push** to your fork and open a **Pull Request** against `main`.

## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` -- A new feature
- `fix:` -- A bug fix
- `doc:` -- Documentation changes
- `refactor:` -- Code refactoring without functional changes
- `chore:` -- Maintenance tasks (CI, dependencies, etc.)
- `test:` -- Adding or updating tests

## Code Style

- **Shell scripts**: Use `#!/bin/bash`, quote variables, and use `set -e` where appropriate.
- **Docker Compose files**: Use the `.yml` extension and follow the existing file structure.
- **Configuration templates**: Use `envsubst`-compatible `${VARIABLE}` placeholders. Do not hardcode domains or credentials.

## Project Structure

Each component lives in its own directory with:

- A `docker-compose.yml` defining its services
- A `compose-wrapper.sh` for configuration generation
- Template files (`.template`) for dynamic configuration

When adding a new component:

1. Create a directory following the `<name>_app` or `<name>_<role>` naming convention
2. Include a `docker-compose.yml` and `compose-wrapper.sh`
3. Use the root `.env` variables for domain configuration
4. Update the `wrapper.sh` startup order if necessary
5. Document the component in `README.md`

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Be kind, constructive, and professional in all interactions.

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.

## License

By contributing to Twake.AI Kickstart, you agree that your contributions will be licensed under the [GNU Affero General Public License v3.0](LICENSE).
