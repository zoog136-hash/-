# Legendary whole-batch checkpoint

Source branch `feature/pr122-legendary-parallel-20261023`, remote-confirmed c23aff8b8fa34b822e6d6012cf272f4a804f4b71. This branch is not merged into PR122/main/PR158; no branch modification or merge was performed.

Fresh actual Git-blob metadata audit, using the SHA-pinned active revision library rather than original draft entries alone: 1319/1320 selected SpriteFrames checked, 0 file-pin mismatches, 0 six-region-count mismatches. The one missing slot is transform:274 / NE / attack. Active selected frames reference 1345 distinct PNG files. These results are not copied historical runtime counts and do not approve pixels, connection, playback, or final quality.

The partial clone fetched individual objects too slowly. The initial read-only PNG audit was interrupted after one actor to batch-fetch selected TRES and PNG objects; no final audit report was emitted and it is not counted as a completed whole-corpus test. The selected TRES batch is complete; PNG batch verification is pending while the one aggregate fetch finishes. No full CI was started.

Prior runtime failure is preserved separately: transform:177 NW hit captured only phases 3,4,5. Capture timing is a hypothesis, not a proved fix. Do not relabel it PASS from TRES metadata. The historical 972-row issue projection is not 972 freshly confirmed defective clips. Final approvals added: 0/1320. Default runtime installations added: 0/1320.

Fresh registration audit: all 821 active registration files read from actual branch blobs. Their 4926 frame entries comprise 4010 explicitly baseline-centered raster origins, 638 corrected-source centered origins with semantic feet/scale unapproved, and 278 without a basis label. None of the 40 staging actors declares native_profile, and the legendary asset subtree has no profile/motion/combined-named resource. This does not make 40 old catalog actors broken: their existing legacy resources remain installed. It blocks treating the new parallel candidates as already native-Player-bound. Authored foot/scale registration and a compatible whole-actor profile are still required; no center coordinate was relabeled as a foot.
