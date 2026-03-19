import { initializeApp, getApps } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyC9O7N5R5LH-MMeINGy6tTM-XUwa7O2Pzs",
  authDomain: "foodchoose-4f82e.firebaseapp.com",
  projectId: "foodchoose-4f82e",
  storageBucket: "foodchoose-4f82e.firebasestorage.app",
  messagingSenderId: "522176211793",
  appId: "1:522176211793:web:foodchoose",
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];

export const auth = getAuth(app);
export const db = getFirestore(app);
