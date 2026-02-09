# Bivium
<p align="left">
  <img src="assets/icon/app_logo.png" width="100" alt="App Logo">
</p>
A Flutter-based LQA & Translation tool that streamlines translation audits with real-time Google Sheets synchronization.

구글 시트와 실시간 연동되어 번역 데이터 수정 및 LQA 검수 효율을 극대화하는 Flutter 기반 현지화 도구.


## 🚀 Getting Started
<a href="https://github.com/red1854th/Bivium/releases/latest">
  <img src="https://img.shields.io/badge/Download-Latest%20Release-blue?style=for-the-badge&logo=github" alt="Download Latest Release">
</a>

## 🛠 Tech Stack & Tools
* **Framework**: Flutter
* **Database**: Google Sheets API v4
* **Language Resource**: [국립국어원 한국어 기초 사전](https://krdict.korean.go.kr/)
* **Development**: 100% AI-assisted (Purely Vibe-Coded)

## 🔍 Description
A professional Flutter tool designed to streamline the Translation and LQA (Language Quality Assurance) process using Google Sheets as a real-time backend.

Key Features

- Live Review & Sync: Seamlessly fetch localized strings from Google Sheets and push corrections instantly during the review process.
    
- Visual Status Tracking: Automatically identifies "Need-to-Fix" items by detecting 'Light Yellow 3' background styles from the sheet.
    
- LQA-Optimized Editor: Tailored interface for comparing source/target strings, managing flags, and documenting QA feedback via the Remark feature.

---
Google Sheets를 데이터베이스로 활용하여 번역 작업 및 LQA 과정을 효율화하는 Flutter 기반 검수 도구입니다.

주요 기능

- 실시간 검수 및 동기화: 구글 시트에 기재된 번역문을 앱에서 즉시 검수하고, 수정 사항을 실시간으로 시트에 반영합니다.

- 시각적 상태 관리: 시트의 'Light Yellow 3' 배경색을 감지하여, 수정이 필요한 항목을 자동으로 식별하고 시각화합니다.

- LQA 특화 에디터: 번역문 비교 및 수정에 최적화된 인터페이스를 제공하며, Remark 기능을 통해 검수 의견을 즉시 기록할 수 있습니다.

- 통계 오타 탐색(Beta): 통계를 통해 빈도수가 낮은 어절을 오타로 판정하여 사용자에게 시각적으로 정보를 제공합니다.