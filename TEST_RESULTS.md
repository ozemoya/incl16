# Verified Activity 16 test results

Main acceptance run commit: 2ce38f4. Fresh-process and two-point checks: ce0dd90.
Android 17 emulator; deployed Cloud Firestore, not a Firestore emulator.
HTTP fixtures and development-only verification faults are explicitly identified.

- T01 2026-11-17T23:15:39.411952Z PASS invalid credentials rejected; valid A authenticated (no credentials logged)
- T02 2026-11-17T23:15:43.811741Z PASS live exact URL returned five validated decoded questions; encoded=Shrimp%20can%20swim%20backwards. decoded=Shrimp can swim backwards.
- T03 2026-11-17T23:15:45.516227Z PASS nonzero code, four items and corrupt encoding each rejected; manual Retry visible
- T04 2026-11-17T23:15:51.533048Z PASS repeated answer ignored; three True answers correct and two incorrect; review contains five entries
- T05 2026-11-17T23:15:57.980346Z PASS replay reset answers and index; distinct IDs suffix=fmqmnP -> tLOhoZ
- T06 2026-11-17T23:16:02.900645Z PASS double-tap guard; exact six-field server record suffix=tLOhoZ timestamp=2026-11-17 23:16:00.254Z cache=false pending=false
- T07 2026-11-17T23:16:03.484159Z PARTIAL same-user sign-out/sign-in server retrieval preserved record; separate process restart test follows
- T08 2026-11-17T23:16:27.114191Z PASS offline never claimed success; reconnect reconciled same suffix=TEUZmc
- T09 2026-11-17T23:16:41.908222Z PASS real commit, injected first verification permission-denied, real retry same suffix=uPBXou unchanged timestamp
- T10 2026-11-17T23:16:42.631952Z PASS real cloud B read and create under A denied permission-denied
- T11 2026-11-17T23:16:43.627105Z PASS real cloud score6, extra field, update denied; original score3 intact
- T12 2026-11-17T23:17:09.210404Z PASS explicitly labeled development hook produced distinct unavailable and resource-exhausted messages after real commits
- T07 2026-11-17T23:20:07.338458Z PASS fresh Android process authenticated A and retrieved original record from server without replay; suffix=tLOhoZ
- T09 2026-11-17T23:20:10.451926Z PASS independent fresh-process read of injected-failure record suffix=uPBXou
- T04 2026-11-17T23:20:17.342206Z PASS exactly two correct selections produced 2/5; remaining three were wrong
