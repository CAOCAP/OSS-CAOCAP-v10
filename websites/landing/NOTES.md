# Landing prototype notes

**Question:** What should the CAOCAP waitlist page look like?

**Verdict:** A light product landing with the **phone in the center** and real app captures around it. The bezel shows Home (CoCaptain and CoStar). Chat and Workspace screenshots float beside it.

Keep:

- Pale field, floating pill nav, two-tone sans headline, one pill waitlist
- Simulator screenshots in `public/app/` — not a CSS mock of the UI
- CoCaptain / CoStar as they appear in the apps
- Explore / Build / Collaborate cards with crops of those captures

Do not return to:

- Chibi hero art or comic chrome
- A drawn canvas / fake nodes as the hero
- Dark editorial splash with no product
- Three layout-switcher variants

The Workspace capture is an empty dotted canvas; that is the current product, not a stand-in mindmap.

## Waitlist

The pill form posts to `/joinWaitlist`. The Cloud Function writes `waitlist/{email}` in Firestore (normalized address, first-seen timestamp). Duplicates and the honeypot field return the same success payload. Nothing is emailed yet.

Vite + React + Tailwind is still a prototype vehicle, not a production stack decision for the web app.
