# Contributing to AuditMySite Studio

Thank you for your interest in contributing to AuditMySite Studio! 

> **Note**: This project is currently in **Early Alpha** stage and under active development. Contribution guidelines will be refined as the project stabilizes.

## 🚧 Current Development Status

- **Phase**: Early Alpha Development
- **Focus**: Core functionality and architecture
- **Target**: Feature parity with [original AuditMySite project](https://github.com/casoon/auditmysite)

## 📋 Before Contributing

Since the project is in early development, please:

1. **Open an Issue First**: Discuss your proposed changes before implementing
2. **Check Current Work**: Review existing issues and pull requests  
3. **Follow Architecture**: Understand the modular design (Engine + Desktop App)

## 🏗️ Project Structure

```
auditmysite_studio/
├── auditmysite_engine/     # Dart audit engine (HTTP API + WebSocket)
├── auditmysite_studio/     # Flutter desktop application  
├── auditmysite_cli/        # Command-line interface
└── shared/                 # Shared models and utilities
```

## 🔧 Development Setup

### Prerequisites
- Flutter SDK (≥3.19.0)
- Dart SDK (≥3.3.0)
- Chrome/Chromium (for Puppeteer)
- Git

### Setup Steps
```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/auditmysite-studio.git
cd auditmysite-studio

# Install dependencies
flutter pub get
cd auditmysite_engine && dart pub get
cd ../auditmysite_studio && flutter pub get
cd ../auditmysite_cli && dart pub get
cd ../shared && dart pub get

# Run tests
flutter test
dart test
```

## 🎯 Areas for Contribution

### High Priority
- [ ] Results visualization and charts
- [ ] Audit history and comparison
- [ ] Export formats (PDF, CSV)
- [ ] Performance optimizations
- [ ] Bug fixes and stability improvements

### Medium Priority  
- [ ] Advanced settings and configuration
- [ ] Additional audit categories
- [ ] UI/UX improvements
- [ ] Documentation enhancements

### Future
- [ ] Plugin architecture
- [ ] Auto-update mechanism  
- [ ] Batch processing
- [ ] Additional platform support

## 📝 Coding Standards

### Dart/Flutter
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` for code formatting
- Run `dart analyze` before committing
- Add tests for new functionality

### Commit Messages
- Use conventional commits format
- Examples:
  - `feat: add PDF export functionality`
  - `fix: resolve WebSocket connection issues`  
  - `docs: update installation instructions`

## 🧪 Testing

- **Engine**: `cd auditmysite_engine && dart test`
- **Flutter App**: `cd auditmysite_studio && flutter test`
- **Integration**: Manual testing with full workflow

## 🔍 Code Review Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'feat: add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## 📋 Pull Request Guidelines

### Before Submitting
- [ ] Code follows project conventions
- [ ] Tests pass (`flutter test`, `dart test`)
- [ ] Code is formatted (`dart format`)
- [ ] No analyzer warnings (`dart analyze`)
- [ ] Documentation is updated if needed

### PR Description
- Clearly describe the problem and solution
- Include the motivation for the change
- List any breaking changes
- Add screenshots for UI changes

## 🐛 Reporting Bugs

### Bug Report Template
```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment:**
- OS: [e.g. macOS 14.0, Windows 11]
- Flutter Version: [e.g. 3.19.0]
- Dart Version: [e.g. 3.3.0]
- App Version: [e.g. v0.1-alpha]

**Additional context**
Add any other context about the problem here.
```

## 💡 Feature Requests

### Feature Request Template
```markdown
**Is your feature request related to a problem?**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions.

**Additional context**
Add any other context or screenshots about the feature request here.
```

## 📞 Getting Help

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/auditmysite-studio/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/auditmysite-studio/discussions)  
- **Original Project**: [casoon/auditmysite](https://github.com/casoon/auditmysite)

## 📄 License

By contributing to AuditMySite Studio, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for helping make AuditMySite Studio better! 🚀**
