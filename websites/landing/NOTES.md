# Landing prototype notes

**Question:** What should the CAOCAP waitlist page look like?

**Verdict:** A light product landing with the **Workspace** in the middle — canvas nodes, CoCaptain chat on the same device. Keep that direction.

The phone is a composed mock of the intended canvas, not a screenshot. Real Workspaces still open empty.

Keep:

- Pale field, floating pill nav, two-tone sans headline, one pill waitlist
- Workspace mock (dotted canvas, glass nodes, in-device chat)
- CoCaptain / CoStar only as they appear in the apps
- Explore / Build / Collaborate as cards with mini UI

Do not return to:

- Chibi hero art or comic chrome
- Empty Home grid as the hero
- Dark editorial splash with no product
- Three layout-switcher variants

## Hosted waitlist

Emails are stored in Firestore through `joinWaitlist`. Keep the submission, pending, error, and remembered-success behavior when changing the design. Vite + React + Tailwind remains a prototype vehicle, not a production web-app stack decision.
