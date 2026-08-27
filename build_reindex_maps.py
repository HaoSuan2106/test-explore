import json, re, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ---- REQ501 reindex: old -> new (active FRs only, reindexed continuously) ----
# Active old REQ501 (IMPLEMENTED/ADAPTED): 1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,19,
#   21,22,23,24,25,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43
# Removed/out-of-scope: 9,10,18,20,26 (replies & share)
old501 = [1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,19,21,22,23,24,25,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43]
map501 = {o: i+1 for i, o in enumerate(old501)}
# new FRs appended after reindex
new_fr_501 = {39: "search", 40: "save/unsave"}

# ---- REQ502 reindex: old -> new ----
# Active old REQ502 (IMPLEMENTED): 1..18,20,21,22,23,26,29..40
# Removed/out-of-scope: 19 (interactive map display), 24,25 (report place withdrawal), 27,28 (share to group)
old502 = list(range(1,19)) + [20,21,22,23,26] + list(range(29,41))
map502 = {o: i+1 for i, o in enumerate(old502)}

# ---- Profile FRs (unchanged) ----
profile = ["REQ103_8","REQ103_11","REQ201_1","REQ201_2","REQ201_5"]

# ---- Constraint renumber within merged UC501 ----
# post constraints keep IDs; collisions resolved:
#  source "C3: Editing Actions" (from old UC502) -> C13
#  profile constraints (from old UC103) C1..C6 -> C18, C19, C21, C26, C30, C31
constraint_map_501 = {
  "C1 Password Policy": "C18 Password Policy",
  "C2 Input Field Verification": "C19 Input Field Verification",
  "C3 Menu Option": "C21 Menu Option",
  "C4 Editable Profile Information": "C26 Editable Profile Information",
  "C5 Exploration Menu Option": "C30 Exploration Menu Option",
  "C6 Exploration Heatmap Generation": "C31 Exploration Heatmap Generation",
  "C3 Editing Actions": "C13 Editing Actions",
}

# ---- Message re-identification (merged UC501) ----
# source M1 used twice: post creation (keep M1) and profile update (re-identified M32)
msg_map = {"M1 Profile updated successfully.": "M32 Profile updated successfully."}

out = {
  "map501": {str(k): str(v) for k, v in map501.items()},
  "map502": {str(k): str(v) for k, v in map502.items()},
  "new_fr_501": new_fr_501,
  "profile_frs": profile,
  "constraint_map_501": constraint_map_501,
  "msg_map": msg_map,
  "count501": len(old501),
  "count502": len(old502),
}
with open(r"C:\Users\HP\OneDrive\Desktop\explorerMy\ExploreMy\reindex_maps.json", "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print("REQ501 count:", len(old501), "-> new IDs 1..", len(old501))
print("REQ502 count:", len(old502), "-> new IDs 1..", len(old502))
print("Map501 sample:", {k: v for k, v in map501.items()})
print("Map502 sample:", {k: v for k, v in map502.items()})
print("constraint_map_501:", constraint_map_501)
print("msg_map:", msg_map)
