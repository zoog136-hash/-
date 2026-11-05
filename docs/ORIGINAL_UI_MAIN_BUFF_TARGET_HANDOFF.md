# Original main Buff display boundary

MainScene80c174a87caf5cfbf910336b64616334ac560ed477f7a663aec58ada70d4285f
has actual Project21896 Set_T_Cen_BuffLayout, original position
(0,592.0001831054688), referencing UI/Main/Set_T_Cen_BuffLayout.csb,
SHA2564954e6ad706466322e31341ac5511e4aa9aa0bd326f3c6928970e3974990706f.
The held HUDScene has no direct Buff Project reference. These are existing
source records, not a newly chosen UI position.

The referenced root120 is an identity Node. Original ListView_Buff5868 has
position(103.752998,-14), extent447x32, anchor(0,0.5), touch enabled;
ListView_DBuff5420 has position(103.752998,-41.9999008), the same extent/anchor.
Both source child arrays are empty. Their serialized itemMargin is0, innerSize
200x300, bounce disabled, clip disabled, directionType/verticalType empty and
horizontalType Align_HorizontalCenter. Those fields do not define a missing
item's size/anchor or justify borrowing the current36x42 generic button.

Other authored nodes are global Btn_ListView2996 / Btn_BuffOpen1532,
its Sp_Bg1912 / Sp_Icon1584 decoration, and Label_Buff964 / Label_Debuff632
with preview+00. The global button's decoration is not an effect OnIcon target.
Neither a total/overflow-count interpretation nor a button mode is inferred.

The actual current caller is renewal_hud.set_quickslot_state's buffs dictionary.
It supplies existing effect.remaining and formatted duration Labels. PR270's
existing describe_buff API owns canonical BuffClass/OnIcon pixels. The missing
contracts are the original per-effect row/image/duration target, its registration
into the empty ListView, and the actual source Buff/Debuff classification field.
No row height, extra image/Label, sorting, polarity or timer is invented.
No adapter is activated by this handoff; current functionality stays intact.
No test, game execution, render, audit, download or CI was started.
