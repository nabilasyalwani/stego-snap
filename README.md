# StegoSnap – Secure Image Steganography App

| No  | Name              | NRP        |
| --- | ----------------- | ---------- |
| 1   | Andi Nur Nabila S | 5025231104 |

---

## Overview

**StegoSnap** adalah aplikasi berbasis **mobile (Flutter)** dengan backend **FastAPI** yang memungkinkan pengguna untuk menyembunyikan (encode) dan mengungkap (decode) pesan rahasia di dalam gambar menggunakan metode **Turtle Shell**.

Aplikasi ini juga terintegrasi dengan **Firebase Firestore** untuk penyimpanan metadata serta fitur **sharing antar user**.

---

## Features

- Encode pesan rahasia ke dalam gambar (Steganografi)
- Decode pesan dari gambar stego
- Upload image langsung dari mobile app
- Download hasil stego image dari server
- Menyimpan metadata hasil encode/decode ke Firestore
- Share stego image ke user lain
- Notification system (accept / decline share)
- Preview image dari server (URL-based)

---

## Tech Stack

### Frontend

- Flutter (Dart)

### Backend

- FastAPI (Python)
- Uvicorn

### Database & Cloud

- Firebase Firestore
- Supabase

### Image Processing

- Turtle Shell Algorithm

---

## Project Structure

```
stego_snap/
│
├── backend/
│   ├── server.py
│   ├── RDHTurtleShell.py
│   ├── uploads/
│   ├── stego-images/
│
├── flutter_app/
│   ├── lib/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── utils/
│   └── pubspec.yaml
│
└── README.md
```

---

## How It Works

### Encode Flow

1. User memilih gambar dari gallery
2. User memasukkan secret message
3. Image dikirim ke backend (FastAPI)
4. Backend menjalankan algoritma RDH
5. Stego image dihasilkan & disimpan di server
6. Client menerima file hasil encode

---

### Decode Flow

1. User memilih gambar stego (file / path)
2. Image dikirim ke backend
3. Backend mengekstrak pesan tersembunyi
4. Hasil decode dikirim kembali ke client

---

## Demo

### YouTube Demo

https://youtu.be/KGn3BBHyDBY
