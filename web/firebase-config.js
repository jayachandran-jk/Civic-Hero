// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getDatabase } from "firebase/database";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDGO_1c2xhgPi0-m0RU_OK9oN-pxRTPSN8",
  authDomain: "civicissue-aae6d.firebaseapp.com",
  projectId: "civicissue-aae6d",
  storageBucket: "civicissue-aae6d.firebasestorage.app",
  messagingSenderId: "559012084553",
  appId: "1:559012084553:web:371c1340ab7d25dc25f898",
  measurementId: "G-VN5FRB53KV"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
export const auth = getAuth(app);

// Initialize Realtime Database and get a reference to the service
export const database = getDatabase(app);
