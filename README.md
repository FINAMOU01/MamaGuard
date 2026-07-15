# MamaGuard

<p align="center">
  <img src="docs/images/logo.png" alt="MamaGuard Logo" width="180"/>
</p>

<p align="center">
  <strong>AI-Powered Maternal Health Monitoring System for Remote Prenatal Care</strong>
</p>

---

## 📖 Overview

MamaGuard is an intelligent maternal health monitoring system designed to support pregnant women through remote prenatal care.

The system combines vital sign monitoring, Artificial Intelligence, and real-time communication technologies to detect potential pregnancy-related risks and facilitate timely communication between patients and healthcare professionals.

MamaGuard is developed as a Final Year Software Engineering Project.

---

## 🎯 Objectives

The main objectives of MamaGuard are to:

- Improve maternal health monitoring between prenatal consultations.
- Detect abnormal maternal vital signs using Artificial Intelligence.
- Assist healthcare professionals through automated risk assessment.
- Notify emergency contacts when abnormal conditions are detected.
- Maintain a history of health measurements.
- Support remote prenatal follow-up.

---

## ✨ Main Features

### 👩 Patient Application

- Phone Number Authentication (OTP)
- PIN Authentication
- Health Measurement Recording
- AI Risk Prediction
- Detailed Health Report
- Health History
- Emergency Contact Management
- Appointment Reminder
- Video Consultation Request
- Profile Management

---

### 👨‍⚕️ Doctor Application

- Professional Registration
- Patient Dashboard
- Risk Notifications
- Patient Medical History
- Appointment Scheduling
- Video Consultation
- Direct Patient Contact

---

### 👨‍💼 Administrator

- Doctor Validation
- Account Management
- System Statistics
- Administrator Management

---

## 🤖 Artificial Intelligence

MamaGuard uses a **Random Forest Machine Learning model** trained on maternal health parameters collected from medically validated thresholds.

The AI classifies patient conditions into three categories:

- 🟢 Normal
- 🟠 Moderate Risk
- 🔴 High Risk

Predictions are accompanied by detailed explanations of abnormal parameters.

---

## 🏗 System Architecture

The system follows:

- Client–Server Architecture
- Modular Monolith Design
- Service-Oriented Design
- Event-Driven Communication

---

## 🛠 Technology Stack

### Mobile

- Flutter
- Dart

### Backend

- Python
- Flask REST API

### Artificial Intelligence

- Scikit-Learn
- Random Forest

### Cloud Services

- Firebase Authentication
- Firebase Firestore
- Firebase Cloud Messaging
- Firebase Cloud Functions

### Communication

- Twilio SMS
- Google Meet API *(Future Work)*

### Development Tools

- Git
- GitHub
- Docker
- Docker Compose

---

## 📂 Project Structure

```
MamaGuard/

│
├── backend/
│   ├── api/
│   ├── ai/
│   └── README.md
│
├── mobile/
│   ├── mamaguard_patient/
│   ├── mamaguard_doctor/
│
├── docs/
│
├── docker/
│
├── .gitignore
│
├── README.md
│
└── LICENSE
```

---

## 🚀 Getting Started

### Clone the repository

```bash
git clone https://github.com/yourusername/MamaGuard.git
```

### Backend

```bash
cd backend/api

pip install -r requirements.txt

python app.py
```

---

### Mobile

```bash
cd mobile/mamaguard_patient

flutter pub get

flutter run
```

---

## 🔄 Workflow

```
Patient

↓

Flutter Mobile Application

↓

Flask REST API

↓

Artificial Intelligence

↓

Risk Assessment

↓

Firestore

↓

Cloud Functions

↓

Firebase Cloud Messaging

↓

Doctor / Patient Notifications
```

---

## 📊 Current Development Status

| Module | Status |
|---------|--------|
| AI Model | ✅ Completed |
| Flask REST API | ✅ Completed |
| Docker | 🔄 In Progress |
| Firebase Authentication | ⏳ Planned |
| Firestore | ⏳ Planned |
| Patient Mobile App | ⏳ Planned |
| Doctor Mobile App | ⏳ Planned |
| Notification System | ⏳ Planned |
| Consultation Module | ⏳ Planned |

---

## 🔒 Security

- OTP Authentication
- PIN Authentication
- Password Hashing
- Firebase Authentication
- Firestore Security Rules
- Role-Based Access Control

---

## 📚 Research Context

MamaGuard is developed as part of a Final Year Software Engineering Project at ICT University.

The project aims to improve maternal healthcare by combining Artificial Intelligence and mobile technologies in resource-limited settings.

---

## 👨‍💻 Author

**FINAMOU Abdoul Belle Grace**

Software Engineering Student

ICT University, Cameroon

---

## 📄 License

This project is developed for academic and research purposes.