# AhamAI - Flutter Chat Application

A powerful AI chat application built with Flutter, featuring multiple AI models, image generation, file uploads, and more.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.1.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Git

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/officialprakashkumarsingh/ahamai.git
cd ahamai
```

2. **Create the environment file**
```bash
# Copy the example environment file
cp .env.example .env
```

3. **Configure your `.env` file**
Open `.env` and add your actual API keys:
```env
# API Configuration
AHAMAI_API_URL=https://ahamai-api.officialprakashkrsingh.workers.dev
AHAMAI_API_KEY=ahamaibyprakash25

# Supabase Configuration
SUPABASE_URL=https://mdoksiisbokvmqsdcguu.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kb2tzaWlzYm9rdm1xc2RjZ3V1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU4NTU3MzcsImV4cCI6MjA3MTQzMTczN30.Sq2eDHc_NgU9Br0zsWdYOr98WSIJS6AsNYaUt3NkbsU

# App Update Configuration
APP_UPDATE_JSON_URL=https://raw.githubusercontent.com/officialprakashkumarsingh/ahamai-landingpage/main/app-update.json
```

4. **Install dependencies**
```bash
flutter pub get
```

5. **Run the app**
```bash
flutter run
```

## 🔑 API Keys Required

The app requires the following API keys to function:

| Key | Description | How to Get |
|-----|-------------|------------|
| `AHAMAI_API_KEY` | Main API for chat models | Contact developer |
| `SUPABASE_URL` | Database URL | [Supabase Dashboard](https://supabase.com) |
| `SUPABASE_ANON_KEY` | Database anonymous key | [Supabase Dashboard](https://supabase.com) |

## 📱 Features

- ✨ Multiple AI chat models
- 🎨 Image generation
- 📁 File upload support (PDF, ZIP, text files)
- 🔍 Built-in web search (automatic with certain models)
- 📊 Charts and diagrams
- 🎯 Quiz and flashcard generation
- 🖼️ Image analysis
- 🎙️ Text-to-speech
- 🌓 Dark/Light theme

## 🏗️ Project Structure

```
lib/
├── core/           # Core services and models
├── features/       # Feature modules
├── shared/         # Shared widgets
├── theme/          # Theme configuration
└── main.dart       # App entry point
```

## 🔒 Security Notes

- Never commit `.env` file to version control
- Keep your API keys secret
- Use different keys for development and production
- The `.env.example` file shows the structure without real keys

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📄 License

This project is proprietary and confidential.

## 👨‍💻 Developer

Prakash Kumar Singh
- GitHub: [@officialprakashkumarsingh](https://github.com/officialprakashkumarsingh)

## 🆘 Troubleshooting

### App shows white screen
- Check if `.env` file exists
- Verify all API keys are correct
- Run `flutter clean && flutter pub get`

### Cannot load environment variables
- Ensure `.env` file is in project root
- Check file permissions
- Verify the format of `.env` file

### Build errors
- Run `flutter doctor` to check setup
- Update Flutter: `flutter upgrade`
- Clear cache: `flutter clean`
