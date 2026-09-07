# Landing waitlist prototype

Vite + React + Tailwind waitlist page. The visual stack is a prototype, not a production web-app decision. Emails are stored in Firestore through the `joinWaitlist` Cloud Function.

There is no send-mail yet. Export addresses from the Firebase console when you write people.

## Run locally

```sh
cd websites/landing
npm install
npm run dev
```

Open the local URL Vite prints (usually `http://localhost:5173`). The dev server proxies `POST /joinWaitlist` to the deployed function.

Hero images in `public/app/` are simulator captures of Home, Workspace, and CoCaptain chat.

## Deploy

```sh
cd websites/landing
npm run build
cd ../../firebase
firebase deploy --only functions,hosting --project caocap-ficruty
```

Hosting copies `websites/landing/dist` into `firebase/hosting-public/` during deploy. That copy is gitignored.
