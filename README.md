# 🚨 Virtual Companion Safety App

A simple and lightweight **personal safety application** built using Flutter. The app continuously tracks user movement and automatically sends an emergency alert with live location details if abnormal inactivity is detected.


## 📌 Overview

Virtual Companion Safety App is designed to help individuals stay safe while walking, jogging, or traveling alone. It works without paid APIs or cloud servers, making it affordable and accessible for everyone.


## 🎯 Problem Statement

Most safety applications rely on paid SMS services, proprietary map APIs, or backend servers. This increases cost and limits accessibility. This project provides a **zero-cost alternative** with real-time tracking and instant alerts.


## ✨ Features

* Real-time GPS tracking
* Automatic inactivity (Dead Man’s Switch) detection
* Emergency alerts via Telegram
* Live GPS coordinates with map link
* Debug panel for monitoring movement data
* Cross-platform support (Android & iOS)


## 🛠️ Tech Stack

* **Flutter** – Cross-platform UI framework
* **Dart** – Programming language
* **OpenStreetMap** – Free map data
* **flutter_map** – Map rendering
* **Geolocator** – Location tracking
* **Telegram Bot API** – Emergency alert messaging


## ⚙️ How It Works

1. User starts tracking in the app
2. GPS location is recorded every few seconds
3. If the user stops moving for a defined duration, a warning is shown
4. If not cancelled, an emergency alert is sent via Telegram with location details


## 🎯 Use Cases

* People walking or jogging alone
* Students commuting late
* Elderly individuals
* Delivery and field workers


## ⚠️ Limitations

* Reduced GPS accuracy indoors
* Requires internet connection
* Initial GPS lock may take time


## 🔮 Future Improvements

* Panic/SOS button
* Multiple emergency contacts
* Fall detection
* Voice-based alerts
* Location history


## 🤝 Contributing

Contributions are welcome and appreciated. You can contribute by:

* Reporting bugs or issues
* Suggesting new features
* Improving documentation
* Submitting pull requests

Please fork the repository and create a pull request with clear commit messages.

---

## 📄 License

This project is licensed under the **MIT License**.

---

## 👤 Author

P Mahalakshmi
GitHub: [https://github.com/Mahalakshmi712]
