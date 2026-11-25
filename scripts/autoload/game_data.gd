extends Node

const NAKAMA_SERVER_URL := "https://arthritis-inquiry-variance-handheld.trycloudflare.com"
const RETIRED_NAKAMA_URLS := [
	"https://mardi-interest-postal-memorabilia.trycloudflare.com",
	"https://bedrooms-value-expand-arch.trycloudflare.com",
]

const WEAPON_ORDER: Array[String] = [
	"basic_pistol",
	"enhanced_pistol",
	"high_caliber_magnum",
	"rapid_pistol",
	"burst_fire_pistol",
	"basic_wand",
	"arcane_wand",
	"advanced_magic_staff",
	"elemental_wand",
	"multi_element_staff",
]

const WEAPONS: Dictionary = {
	"basic_pistol": {
		"id": "basic_pistol", "name": "Basic Pistol", "category": "pistol", "role": "Reliable Single-Shot",
		"tier": 1, "parent_id": "", "damage": 24, "fire_rate": 3.4, "reload_time": 1.15, "mag_size": 12,
		"mana_cost": 0, "crit_chance": 0.1, "projectile_speed": 740.0, "penetration": 1, "projectiles_per_shot": 1,
		"spread_rad": 0.03, "aoe_radius": 0.0, "range": 560.0, "color": "#F59E0B", "cost_points": 0, "cost_tokens": 0
	},
	"enhanced_pistol": {
		"id": "enhanced_pistol", "name": "Enhanced Pistol", "category": "pistol", "role": "High Accuracy & Piercing",
		"tier": 2, "parent_id": "basic_pistol", "damage": 36, "fire_rate": 3.8, "reload_time": 1.0, "mag_size": 15,
		"mana_cost": 0, "crit_chance": 0.16, "projectile_speed": 840.0, "penetration": 2, "projectiles_per_shot": 1,
		"spread_rad": 0.018, "aoe_radius": 0.0, "range": 640.0, "color": "#FBBF24", "cost_points": 180, "cost_tokens": 0
	},
	"high_caliber_magnum": {
		"id": "high_caliber_magnum", "name": "High-Caliber Magnum", "category": "pistol", "role": "Heavy Armor Piercer",
		"tier": 3, "parent_id": "enhanced_pistol", "damage": 78, "fire_rate": 2.3, "reload_time": 1.25, "mag_size": 8,
		"mana_cost": 0, "crit_chance": 0.28, "projectile_speed": 980.0, "penetration": 4, "projectiles_per_shot": 1,
		"spread_rad": 0.01, "aoe_radius": 0.0, "range": 740.0, "color": "#F97316", "cost_points": 480, "cost_tokens": 2
	},
	"rapid_pistol": {
		"id": "rapid_pistol", "name": "Rapid Pistol", "category": "pistol", "role": "Fast Suppression Fire",
		"tier": 2, "parent_id": "basic_pistol", "damage": 21, "fire_rate": 6.4, "reload_time": 0.95, "mag_size": 22,
		"mana_cost": 0, "crit_chance": 0.12, "projectile_speed": 800.0, "penetration": 1, "projectiles_per_shot": 1,
		"spread_rad": 0.06, "aoe_radius": 0.0, "range": 560.0, "color": "#38BDF8", "cost_points": 200, "cost_tokens": 0
	},
	"burst_fire_pistol": {
		"id": "burst_fire_pistol", "name": "Burst-Fire Pistol", "category": "pistol", "role": "3-Round Fan Salvo",
		"tier": 3, "parent_id": "rapid_pistol", "damage": 25, "fire_rate": 4.5, "reload_time": 1.05, "mag_size": 24,
		"mana_cost": 0, "crit_chance": 0.18, "projectile_speed": 860.0, "penetration": 2, "projectiles_per_shot": 3,
		"spread_rad": 0.14, "aoe_radius": 0.0, "range": 580.0, "color": "#0EA5E9", "cost_points": 500, "cost_tokens": 2
	},
	"basic_wand": {
		"id": "basic_wand", "name": "Pulse Sidearm", "category": "magic", "role": "Short-Range Energy Burst",
		"tier": 1, "parent_id": "", "damage": 28, "fire_rate": 2.6, "reload_time": 0.0, "mag_size": 0,
		"mana_cost": 8, "crit_chance": 0.12, "projectile_speed": 620.0, "penetration": 1, "projectiles_per_shot": 1,
		"spread_rad": 0.02, "aoe_radius": 34.0, "range": 520.0, "color": "#38BDF8", "cost_points": 0, "cost_tokens": 0
	},
	"arcane_wand": {
		"id": "arcane_wand", "name": "Piercing Sidearm", "category": "magic", "role": "Piercing Energy Pulse",
		"tier": 2, "parent_id": "basic_wand", "damage": 42, "fire_rate": 3.1, "reload_time": 0.0, "mag_size": 0,
		"mana_cost": 9, "crit_chance": 0.18, "projectile_speed": 700.0, "penetration": 2, "projectiles_per_shot": 1,
		"spread_rad": 0.015, "aoe_radius": 56.0, "range": 600.0, "color": "#6366F1", "cost_points": 200, "cost_tokens": 0
	},
	"advanced_magic_staff": {
		"id": "advanced_magic_staff", "name": "Heavy Pulse Rifle", "category": "magic", "role": "Heavy Area Detonation",
		"tier": 3, "parent_id": "arcane_wand", "damage": 74, "fire_rate": 2.5, "reload_time": 0.0, "mag_size": 0,
		"mana_cost": 13, "crit_chance": 0.24, "projectile_speed": 740.0, "penetration": 3, "projectiles_per_shot": 1,
		"spread_rad": 0.01, "aoe_radius": 92.0, "range": 680.0, "color": "#8B5CF6", "cost_points": 520, "cost_tokens": 2
	},
	"elemental_wand": {
		"id": "elemental_wand", "name": "Twin Pulse Sidearm", "category": "magic", "role": "Twin Energy Bolts",
		"tier": 2, "parent_id": "basic_wand", "damage": 26, "fire_rate": 3.3, "reload_time": 0.0, "mag_size": 0,
		"mana_cost": 10, "crit_chance": 0.16, "projectile_speed": 680.0, "penetration": 1, "projectiles_per_shot": 2,
		"spread_rad": 0.16, "aoe_radius": 44.0, "range": 560.0, "color": "#10B981", "cost_points": 220, "cost_tokens": 0
	},
	"multi_element_staff": {
		"id": "multi_element_staff", "name": "Scatter Pulse Rifle", "category": "magic", "role": "4-Bolt Energy Spread",
		"tier": 3, "parent_id": "elemental_wand", "damage": 32, "fire_rate": 3.2, "reload_time": 0.0, "mag_size": 0,
		"mana_cost": 14, "crit_chance": 0.22, "projectile_speed": 720.0, "penetration": 2, "projectiles_per_shot": 4,
		"spread_rad": 0.28, "aoe_radius": 58.0, "range": 620.0, "color": "#14B8A6", "cost_points": 550, "cost_tokens": 2
	},
}

const CLASS_SKILLS: Dictionary = {
	"ranger": ["grenade", "machine_gun", "tactical_clone", "ranger_dash", "ranger_ultimate"],
	"medic": ["arcane_nova", "frost_ring", "ranger_dash", "healing_totem", "medic_revive_ultimate"],
}

const SKILLS: Dictionary = {
	"grenade": {
		"id": "grenade", "name": "Frag Grenade", "key_hint": "Q",
		"description": "Throws a high-explosive grenade dealing heavy blast AoE damage.",
		"cooldown": 6.0, "mana_cost": 0, "color": "#F97316", "unlock_wave": 1,
		"charge_cost_coins": 25, "upgrade_cost_coins": 55, "max_charges": 12, "max_upgrade_level": 5
	},
	"machine_gun": {
		"id": "machine_gun", "name": "Machine Gun", "key_hint": "E",
		"description": "Equips a rapid-fire heavy machine gun overdrive for 4.5s.",
		"cooldown": 9.5, "mana_cost": 0, "color": "#F59E0B", "unlock_wave": 2,
		"charge_cost_coins": 40, "upgrade_cost_coins": 70, "max_charges": 10, "max_upgrade_level": 5
	},
	"tactical_clone": {
		"id": "tactical_clone", "name": "Heavy Clones", "key_hint": "F",
		"description": "Spawns 2 tactical Ranger clones armed with high-caliber heavy weapons.",
		"cooldown": 14.0, "mana_cost": 0, "color": "#22C55E", "unlock_wave": 2,
		"charge_cost_coins": 45, "upgrade_cost_coins": 75, "max_charges": 8, "max_upgrade_level": 5
	},
	"ranger_dash": {
		"id": "ranger_dash", "name": "Tactical Dash", "key_hint": "Space",
		"description": "Quick burst movement with brief dodge invulnerability.",
		"cooldown": 3.2, "mana_cost": 0, "color": "#FBBF24", "unlock_wave": 1,
		"charge_cost_coins": 15, "upgrade_cost_coins": 45, "max_charges": 15, "max_upgrade_level": 5
	},
	"ranger_ultimate": {
		"id": "ranger_ultimate", "name": "Bullet Storm", "key_hint": "X",
		"description": "Ultimate airstrike & 360° heavy-caliber barrage across the battlefield.",
		"cooldown": 19.0, "mana_cost": 0, "color": "#EF4444", "unlock_wave": 3,
		"charge_cost_coins": 65, "upgrade_cost_coins": 95, "max_charges": 6, "max_upgrade_level": 5
	},
	"arcane_nova": {
		"id": "arcane_nova", "name": "Repulse Pulse", "key_hint": "Q",
		"description": "Pushes back nearby zombies with a damaging shockwave.",
		"cooldown": 6.5, "mana_cost": 22, "color": "#38BDF8", "unlock_wave": 1,
		"charge_cost_coins": 25, "upgrade_cost_coins": 55, "max_charges": 12, "max_upgrade_level": 5
	},
	"frost_ring": {
		"id": "frost_ring", "name": "Cryo Ring", "key_hint": "E",
		"description": "Chills and slows nearby zombies by 60% for 3.5s.",
		"cooldown": 9.0, "mana_cost": 25, "color": "#60A5FA", "unlock_wave": 2,
		"charge_cost_coins": 30, "upgrade_cost_coins": 65, "max_charges": 10, "max_upgrade_level": 5
	},
	"healing_totem": {
		"id": "healing_totem", "name": "Field Medkit", "key_hint": "F",
		"description": "Restores 35%+ HP instantly and clears slow hazards.",
		"cooldown": 13.5, "mana_cost": 20, "color": "#22C55E", "unlock_wave": 2,
		"charge_cost_coins": 35, "upgrade_cost_coins": 65, "max_charges": 10, "max_upgrade_level": 5
	},
	"medic_revive_ultimate": {
		"id": "medic_revive_ultimate", "name": "Emergency Revival", "key_hint": "X",
		"description": "Revives downed teammates.",
		"cooldown": 19.0, "mana_cost": 0, "color": "#2DD4BF", "unlock_wave": 3,
		"charge_cost_coins": 65, "upgrade_cost_coins": 95, "max_charges": 6, "max_upgrade_level": 5
	},
}

const ENEMIES: Dictionary = {
	"basic": {
		"type": "basic", "name": "Walker Zombie", "base_hp": 46, "base_damage": 12, "speed": 98.0,
		"radius": 17.0, "color": "#4D7C0F", "accent_color": "#84CC16", "points_reward": 5, "xp_reward": 12,
		"policy": "chaser", "passes_walls": false
	},
	"fast": {
		"type": "fast", "name": "Sprinter Zombie", "base_hp": 34, "base_damage": 14, "speed": 172.0,
		"radius": 14.0, "color": "#0D9488", "accent_color": "#2DD4BF", "points_reward": 10, "xp_reward": 18,
		"policy": "flanker", "passes_walls": false
	},
	"tank": {
		"type": "tank", "name": "Tank Brute", "base_hp": 145, "base_damage": 24, "speed": 74.0,
		"radius": 25.0, "color": "#581C87", "accent_color": "#A855F7", "points_reward": 25, "xp_reward": 38,
		"policy": "charger", "passes_walls": false
	},
	"elite": {
		"type": "elite", "name": "Spitter Elite", "base_hp": 88, "base_damage": 18, "speed": 108.0,
		"radius": 19.0, "color": "#B91C1C", "accent_color": "#F87171", "points_reward": 30, "xp_reward": 45,
		"policy": "kiter", "passes_walls": false
	},
	"spirit": {
		"type": "spirit", "name": "Phantom Spirit", "base_hp": 42, "base_damage": 15, "speed": 118.0,
		"radius": 15.0, "color": "#0E7490", "accent_color": "#67E8F9", "points_reward": 18, "xp_reward": 26,
		"policy": "chaser", "passes_walls": true
	},
	"flying": {
		"type": "flying", "name": "Blight Wing", "base_hp": 36, "base_damage": 13, "speed": 148.0,
		"radius": 15.0, "color": "#7C2D12", "accent_color": "#FB923C", "points_reward": 16, "xp_reward": 22,
		"policy": "flanker", "passes_walls": true
	},
}

const BOSSES: Dictionary = {
	"village_boss": {
		"id": "village_boss", "name": "Chief Rotjaw", "title": "Mutated Village Chief", "stage_id": 1,
		"base_hp": 680, "base_damage": 26, "speed": 92.0, "radius": 38.0, "color": "#65A30D",
		"accent_color": "#F59E0B", "points_reward": 250, "token_reward": 2, "xp_reward": 180, "attack_pattern": "slam"
	},
	"forest_boss": {
		"id": "forest_boss", "name": "Blightfang", "title": "Giant Infected Beast", "stage_id": 2,
		"base_hp": 960, "base_damage": 30, "speed": 118.0, "radius": 42.0, "color": "#15803D",
		"accent_color": "#4ADE80", "points_reward": 320, "token_reward": 2, "xp_reward": 240, "attack_pattern": "charge"
	},
	"city_boss": {
		"id": "city_boss", "name": "Iron Bastion", "title": "Armored Warlord Zombie", "stage_id": 3,
		"base_hp": 1320, "base_damage": 34, "speed": 86.0, "radius": 44.0, "color": "#475569",
		"accent_color": "#F97316", "points_reward": 400, "token_reward": 3, "xp_reward": 320, "attack_pattern": "barrage"
	},
	"laboratory_boss": {
		"id": "laboratory_boss", "name": "Subject X-09", "title": "Failed Experiment", "stage_id": 4,
		"base_hp": 1650, "base_damage": 38, "speed": 108.0, "radius": 42.0, "color": "#7E22CE",
		"accent_color": "#22D3EE", "points_reward": 480, "token_reward": 3, "xp_reward": 400, "attack_pattern": "toxic"
	},
	"final_boss": {
		"id": "final_boss", "name": "Malakor Prime", "title": "Final Mutant Overlord", "stage_id": 5,
		"base_hp": 2200, "base_damage": 44, "speed": 104.0, "radius": 48.0, "color": "#991B1B",
		"accent_color": "#FACC15", "points_reward": 700, "token_reward": 5, "xp_reward": 600, "attack_pattern": "overlord"
	},
	"infected_maya": {
		"id": "infected_maya", "name": "Infected Ranger Maya", "title": "Fallen Scout", "stage_id": 5,
		"base_hp": 1600, "base_damage": 34, "speed": 112.0, "radius": 36.0, "color": "#4D7C0F",
		"accent_color": "#BEF264", "points_reward": 500, "token_reward": 3, "xp_reward": 420, "attack_pattern": "maya_rifle"
	},
	"human_tumbleweed": {
		"id": "human_tumbleweed", "name": "Human Tumbleweed", "title": "Infected Maya and the Fallen", "stage_id": 5,
		"base_hp": 2600, "base_damage": 48, "speed": 105.0, "radius": 54.0, "color": "#556434",
		"accent_color": "#BEF264", "points_reward": 850, "token_reward": 5, "xp_reward": 700, "attack_pattern": "tumbleweed"
	},
}

const BUNKER_SHOP_ORDER: Array[String] = [
	"ammo_medkit",
	"build_wall",
	"build_spike",
	"build_turret",
	"damage_boost",
	"armor_plate",
	"mana_core",
	"revive_kit",
]

const BUNKER_SHOP_ITEMS: Dictionary = {
	"ammo_medkit": {
		"id": "ammo_medkit", "name": "Field Resupply", "category": "supply", "cost_coins": 25,
		"min_stage": 1, "description": "Refills magazine + restores 45 HP immediately.", "color": "#22C55E", "defense_kind": ""
	},
	"build_wall": {
		"id": "build_wall", "name": "Barricade Wall", "category": "build", "cost_coins": 35,
		"min_stage": 1, "description": "Build a 360 HP defensive wall outside the bunker.", "color": "#94A3B8", "defense_kind": "wall"
	},
	"build_spike": {
		"id": "build_spike", "name": "Spike Trap", "category": "build", "cost_coins": 30,
		"min_stage": 1, "description": "Floor spikes that deal damage & slow zombies by 45%.", "color": "#F59E0B", "defense_kind": "spike_trap"
	},
	"build_turret": {
		"id": "build_turret", "name": "Sentry Turret", "category": "build", "cost_coins": 85,
		"min_stage": 1, "description": "Automated bunker gun turret firing at nearby zombies.", "color": "#38BDF8", "defense_kind": "turret"
	},
	"damage_boost": {
		"id": "damage_boost", "name": "Hollow-Point Rounds", "category": "upgrade", "cost_coins": 70,
		"min_stage": 1, "description": "+15% weapon damage for the rest of the run.", "color": "#F97316", "defense_kind": ""
	},
	"armor_plate": {
		"id": "armor_plate", "name": "Kevlar Armor Plate", "category": "upgrade", "cost_coins": 60,
		"min_stage": 1, "description": "+35 Max HP and restores 35 HP.", "color": "#10B981", "defense_kind": ""
	},
	"mana_core": {
		"id": "mana_core", "name": "Backup Battery", "category": "upgrade", "cost_coins": 55,
		"min_stage": 2, "description": "+35 max energy and a full recharge.", "color": "#6366F1", "defense_kind": ""
	},
	"revive_kit": {
		"id": "revive_kit", "name": "Squad Defib Charge", "category": "supply", "cost_coins": 75,
		"min_stage": 1, "description": "Online Co-op: Revives downed teammates & heals squad +30 HP.", "color": "#EC4899", "defense_kind": ""
	},
}

const STAGES: Array[Dictionary] = [
	{
		"id": 1, "name": "Abandoned Village", "subtitle": "Overrun timber cabins & cobblestone plaza",
		"boss_id": "village_boss", "waves_count": 3, "map_width": 2500.0, "map_height": 1200.0,
		"floor_color": "#4D6B3C", "floor_grid_color": "#425E33", "accent_color": "#84CC16",
		"enemy_mix": ["basic", "fast", "tank", "spirit", "flying"],
		"obstacles": [
			{"x": 260, "y": 170, "w": 130, "h": 86, "color": "#92400E", "kind": "crate"},
			{"x": 260, "y": 920, "w": 130, "h": 86, "color": "#92400E", "kind": "crate"},
			{"x": 1010, "y": 170, "w": 80, "h": 120, "color": "#78716C", "kind": "wall"},
			{"x": 1010, "y": 910, "w": 80, "h": 120, "color": "#78716C", "kind": "wall"},
			{"x": 1640, "y": 180, "w": 130, "h": 86, "color": "#92400E", "kind": "crate"},
			{"x": 1640, "y": 920, "w": 130, "h": 86, "color": "#92400E", "kind": "crate"},
			{"x": 680, "y": 180, "w": 130, "h": 72, "color": "#713F12", "kind": "hazard", "hazard_type": "mud"},
		],
		"lanterns": [
			{"x": 340, "y": 600, "radius": 240, "color": "#FDE68A"},
			{"x": 1060, "y": 600, "radius": 260, "color": "#FDE68A"},
			{"x": 2040, "y": 600, "radius": 280, "color": "#FDE68A"},
		],
		"bunkers": [
			{"id": "v_b1", "name": "Timber Watchpost", "x": 740.0, "y": 600.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "v_b2", "name": "Chapel Bunker", "x": 1380.0, "y": 600.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "v_b3", "name": "Village Extraction Tower", "x": 2040.0, "y": 600.0, "radius": 192.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		],
	},
	{
		"id": 2, "name": "Dark Forest", "subtitle": "Dense pines, mire bogs & prowling packs",
		"boss_id": "forest_boss", "waves_count": 4, "map_width": 2950.0, "map_height": 1250.0,
		"floor_color": "#264331", "floor_grid_color": "#1E3627", "accent_color": "#22C55E",
		"enemy_mix": ["basic", "fast", "tank", "elite", "spirit", "flying"],
		"obstacles": [
			{"x": 260, "y": 190, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 260, "y": 940, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 960, "y": 180, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 960, "y": 950, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 1620, "y": 180, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 1620, "y": 950, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 2240, "y": 190, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 2240, "y": 950, "w": 92, "h": 92, "color": "#14532D", "kind": "tree"},
			{"x": 640, "y": 210, "w": 120, "h": 80, "color": "#3F6212", "kind": "hazard", "hazard_type": "mud"},
			{"x": 1320, "y": 960, "w": 120, "h": 80, "color": "#3F6212", "kind": "hazard", "hazard_type": "mud"},
		],
		"lanterns": [
			{"x": 680, "y": 625, "radius": 240, "color": "#BBF7D0"},
			{"x": 1320, "y": 625, "radius": 250, "color": "#FDE68A"},
			{"x": 2600, "y": 625, "radius": 280, "color": "#BBF7D0"},
		],
		"bunkers": [
			{"id": "f_b1", "name": "Ranger Cabin", "x": 680.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "f_b2", "name": "Pine Clearing Tower", "x": 1320.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "f_b3", "name": "Creek Fort", "x": 1960.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "f_b4", "name": "Forest Helipad Bunker", "x": 2600.0, "y": 625.0, "radius": 192.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		],
	},
	{
		"id": 3, "name": "Destroyed City", "subtitle": "Shattered boulevards & concrete barricades",
		"boss_id": "city_boss", "waves_count": 4, "map_width": 3000.0, "map_height": 1250.0,
		"floor_color": "#374151", "floor_grid_color": "#2D3644", "accent_color": "#F59E0B",
		"enemy_mix": ["basic", "fast", "tank", "elite", "spirit", "flying"],
		"obstacles": [
			{"x": 280, "y": 200, "w": 170, "h": 56, "color": "#64748B", "kind": "wall"},
			{"x": 280, "y": 980, "w": 170, "h": 56, "color": "#64748B", "kind": "wall"},
			{"x": 1120, "y": 200, "w": 170, "h": 56, "color": "#64748B", "kind": "wall"},
			{"x": 1120, "y": 980, "w": 170, "h": 56, "color": "#64748B", "kind": "wall"},
			{"x": 1940, "y": 190, "w": 76, "h": 110, "color": "#B45309", "kind": "crate"},
			{"x": 1940, "y": 950, "w": 76, "h": 110, "color": "#B45309", "kind": "crate"},
			{"x": 760, "y": 200, "w": 140, "h": 72, "color": "#991B1B", "kind": "hazard", "hazard_type": "lava"},
		],
		"lanterns": [
			{"x": 680, "y": 625, "radius": 240, "color": "#FCD34D"},
			{"x": 1320, "y": 625, "radius": 240, "color": "#FCD34D"},
			{"x": 2620, "y": 625, "radius": 280, "color": "#FDE68A"},
		],
		"bunkers": [
			{"id": "c_b1", "name": "Subway Checkpoint", "x": 680.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "c_b2", "name": "Bank Vault Bunker", "x": 1320.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "c_b3", "name": "Overpass Bastion", "x": 1960.0, "y": 625.0, "radius": 180.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
			{"id": "c_b4", "name": "Citadel Command Tower", "x": 2620.0, "y": 625.0, "radius": 192.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		],
	},
	{
		"id": 4, "name": "Research Facility", "subtitle": "Bio-containment floors & leaking chemical vats",
		"boss_id": "laboratory_boss", "waves_count": 5, "map_width": 3450.0, "map_height": 1250.0,
		"floor_color": "#2B3A4A", "floor_grid_color": "#22303F", "accent_color": "#06B6D4",
		"enemy_mix": ["fast", "tank", "elite", "spirit", "flying"],
		"obstacles": [
			{"x": 300, "y": 200, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 300, "y": 950, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 1220, "y": 200, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 1220, "y": 950, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 2140, "y": 200, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 2140, "y": 950, "w": 96, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 760, "y": 200, "w": 120, "h": 75, "color": "#15803D", "kind": "hazard", "hazard_type": "toxic"},
			{"x": 1680, "y": 960, "w": 120, "h": 75, "color": "#15803D", "kind": "hazard", "hazard_type": "toxic"},
		],
		"lanterns": [
			{"x": 640, "y": 625, "radius": 240, "color": "#67E8F9"},
			{"x": 1880, "y": 625, "radius": 250, "color": "#67E8F9"},
			{"x": 3120, "y": 625, "radius": 290, "color": "#A5F3FC"},
		],
		"bunkers": [
			{"id": "l_b1", "name": "Decontam Airlock A", "x": 640.0, "y": 625.0, "radius": 176.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "l_b2", "name": "Cryo Lab Bunker", "x": 1260.0, "y": 625.0, "radius": 176.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "l_b3", "name": "Reactor Core Pod", "x": 1880.0, "y": 625.0, "radius": 176.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "l_b4", "name": "Bio-Shield Vault", "x": 2500.0, "y": 625.0, "radius": 176.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "l_b5", "name": "Mainframe Extraction Lift", "x": 3120.0, "y": 625.0, "radius": 190.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		],
	},
	{
		"id": 5, "name": "The Deadlands", "subtitle": "Ash plains, obsidian spires & molten rifts",
		"boss_id": "final_boss", "waves_count": 5, "map_width": 3550.0, "map_height": 1300.0,
		"floor_color": "#3A2626", "floor_grid_color": "#2E1D1D", "accent_color": "#EF4444",
		"enemy_mix": ["basic", "fast", "tank", "elite", "spirit", "flying"],
		"obstacles": [
			{"x": 320, "y": 200, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 320, "y": 1000, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 1320, "y": 200, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 1320, "y": 1000, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 2240, "y": 200, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 2240, "y": 1000, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 840, "y": 200, "w": 170, "h": 68, "color": "#DC2626", "kind": "hazard", "hazard_type": "lava"},
			{"x": 1760, "y": 1010, "w": 170, "h": 68, "color": "#DC2626", "kind": "hazard", "hazard_type": "lava"},
		],
		"lanterns": [
			{"x": 660, "y": 650, "radius": 240, "color": "#FCA5A5"},
			{"x": 1900, "y": 650, "radius": 250, "color": "#FDBA74"},
			{"x": 3160, "y": 650, "radius": 300, "color": "#FCA5A5"},
		],
		"bunkers": [
			{"id": "d_b1", "name": "Ash Trench Shelter", "x": 660.0, "y": 650.0, "radius": 178.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "d_b2", "name": "Obsidian Watchtower", "x": 1280.0, "y": 650.0, "radius": 178.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "d_b3", "name": "Rift Fortification", "x": 1900.0, "y": 650.0, "radius": 178.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "d_b4", "name": "Forward Vanguard Post", "x": 2520.0, "y": 650.0, "radius": 178.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
			{"id": "d_b5", "name": "Omega Extraction Citadel", "x": 3160.0, "y": 650.0, "radius": 192.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		],
	},
]

const ENDLESS_PORTAL_REALMS: Array[Dictionary] = [
	{
		"realm_number": 1, "name": "Shattered Outpost", "subtitle": "Reinforced concrete perimeter & relay bunkers",
		"floor_color": "#36453B", "floor_grid_color": "#2B382F", "accent_color": "#F59E0B",
		"obstacles": [
			{"x": 240, "y": 200, "w": 120, "h": 76, "color": "#78716C", "kind": "wall"},
			{"x": 2240, "y": 200, "w": 120, "h": 76, "color": "#78716C", "kind": "wall"},
			{"x": 240, "y": 1120, "w": 120, "h": 76, "color": "#78716C", "kind": "wall"},
			{"x": 2240, "y": 1120, "w": 120, "h": 76, "color": "#78716C", "kind": "wall"},
			{"x": 960, "y": 1100, "w": 110, "h": 66, "color": "#92400E", "kind": "crate"},
			{"x": 1680, "y": 1100, "w": 110, "h": 66, "color": "#92400E", "kind": "crate"},
		],
	},
	{
		"realm_number": 2, "name": "Toxic Wasteland", "subtitle": "Acid marshes & corroded containment ruins",
		"floor_color": "#253D32", "floor_grid_color": "#1B2E26", "accent_color": "#22C55E",
		"obstacles": [
			{"x": 260, "y": 220, "w": 100, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 2260, "y": 220, "w": 100, "h": 96, "color": "#475569", "kind": "pillar"},
			{"x": 880, "y": 1100, "w": 150, "h": 70, "color": "#15803D", "kind": "hazard", "hazard_type": "toxic"},
			{"x": 1700, "y": 1100, "w": 150, "h": 70, "color": "#15803D", "kind": "hazard", "hazard_type": "toxic"},
			{"x": 1860, "y": 210, "w": 110, "h": 70, "color": "#64748B", "kind": "wall"},
		],
	},
	{
		"realm_number": 3, "name": "Cyber Ruins", "subtitle": "Overloaded power pylons & obsidian street grids",
		"floor_color": "#232B3E", "floor_grid_color": "#1A2030", "accent_color": "#38BDF8",
		"obstacles": [
			{"x": 260, "y": 210, "w": 130, "h": 66, "color": "#334155", "kind": "wall"},
			{"x": 2220, "y": 210, "w": 130, "h": 66, "color": "#334155", "kind": "wall"},
			{"x": 260, "y": 1120, "w": 130, "h": 66, "color": "#334155", "kind": "wall"},
			{"x": 2220, "y": 1120, "w": 130, "h": 66, "color": "#334155", "kind": "wall"},
			{"x": 1290, "y": 1110, "w": 130, "h": 72, "color": "#0369A1", "kind": "pillar"},
		],
	},
	{
		"realm_number": 4, "name": "Crimson Rift", "subtitle": "Molten fissures & volcanic obsidian pillars",
		"floor_color": "#3C2326", "floor_grid_color": "#2E1A1D", "accent_color": "#EF4444",
		"obstacles": [
			{"x": 260, "y": 210, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 2260, "y": 210, "w": 96, "h": 96, "color": "#1F2937", "kind": "pillar"},
			{"x": 880, "y": 1110, "w": 165, "h": 66, "color": "#DC2626", "kind": "hazard", "hazard_type": "lava"},
			{"x": 1700, "y": 1110, "w": 165, "h": 66, "color": "#DC2626", "kind": "hazard", "hazard_type": "lava"},
			{"x": 1860, "y": 210, "w": 110, "h": 80, "color": "#4B5563", "kind": "wall"},
		],
	},
	{
		"realm_number": 5, "name": "Astral Citadel", "subtitle": "Void-forged bastions & arcane energy conduits",
		"floor_color": "#2B2442", "floor_grid_color": "#211B33", "accent_color": "#A855F7",
		"obstacles": [
			{"x": 280, "y": 210, "w": 110, "h": 86, "color": "#4C1D95", "kind": "pillar"},
			{"x": 2220, "y": 210, "w": 110, "h": 86, "color": "#4C1D95", "kind": "pillar"},
			{"x": 280, "y": 1110, "w": 110, "h": 86, "color": "#4C1D95", "kind": "pillar"},
			{"x": 2220, "y": 1110, "w": 110, "h": 86, "color": "#4C1D95", "kind": "pillar"},
			{"x": 1290, "y": 1120, "w": 140, "h": 64, "color": "#334155", "kind": "wall"},
		],
	},
]

const ENDLESS_ARENA: Dictionary = {
	"id": 99, "name": "Endless Outpost", "subtitle": "Multi-bunker survival with 10-wave Dimensional Portals",
	"boss_id": "city_boss", "waves_count": 9999, "map_width": 2750.0, "map_height": 1450.0,
	"floor_color": "#36453B", "floor_grid_color": "#2B382F", "accent_color": "#F59E0B",
	"enemy_mix": ["basic", "fast", "tank", "elite", "spirit", "flying"],
	"obstacles": [],
	"lanterns": [
		{"x": 600, "y": 780, "radius": 260, "color": "#FDE68A"},
		{"x": 1360, "y": 780, "radius": 300, "color": "#FDE68A"},
		{"x": 1360, "y": 290, "radius": 260, "color": "#BAE6FD"},
		{"x": 2140, "y": 780, "radius": 280, "color": "#FDE68A"},
	],
	"bunkers": [
		{"id": "e_b1", "name": "West Relay Bunker", "x": 600.0, "y": 780.0, "radius": 182.0, "revive_offset_x": -320.0, "revive_offset_y": 0.0},
		{"id": "e_b2", "name": "Central Stronghold", "x": 1360.0, "y": 780.0, "radius": 190.0, "revive_offset_x": -330.0, "revive_offset_y": 0.0},
		{"id": "e_b3", "name": "North Watch Citadel", "x": 1360.0, "y": 290.0, "radius": 176.0, "revive_offset_x": -315.0, "revive_offset_y": 0.0},
		{"id": "e_b4", "name": "East Extraction Fort", "x": 2140.0, "y": 780.0, "radius": 186.0, "revive_offset_x": -325.0, "revive_offset_y": 0.0},
	],
}

const STORY_CHAPTERS: Dictionary = {
	1: {
		"badge": "CHAPTER 01 · OUTBREAK ZERO", "title": "Abandoned Village", "subtitle": "Overrun timber cabins & cobblestone plaza",
		"what_happened": [
			"A contaminated supply convoy crashed on the village road at dawn, turning the garrison within hours.",
			"Survivors welded the Timber Watchpost and Chapel Bunker doors—sector barriers seal ahead until each wave falls.",
			"Hold the perimeter doorways, watch for drifting Phantom Spirits, and break through to the Extraction Tower.",
		],
		"threat_note": "Bunker walls block ground walkers and gunfire—only Phantom Spirits & Blight Wings can pass straight through walls!",
		"boss_id": "village_boss",
		"boss_summary": "Chief Rotjaw — Mutated Village Chief who crushes defenses with heavy ground slams and shockwaves.",
		"accent_color": "#84CC16", "floor_color": "#4D6B3C",
		"manga_panels": [
			{"id": "s1_p1", "scene_kind": "crash", "speaker": "SCOUT MAYA", "dialogue": "Convoy 07 is burning! The infection hit the village at sunrise!", "narration": "06:14 HRS — The quarantine perimeter collapses in smoke.", "sfx": "KRAAASH!!", "mood_color": "#84CC16"},
			{"id": "s1_p2", "scene_kind": "barricade", "speaker": "RANGER LEAD", "dialogue": "Seal the Watchpost masonry! Sector barrier stays locked until Wave 1 falls!", "narration": "Brick walls hold back walkers and stray gunfire.", "sfx": "KLANK!!", "mood_color": "#38BDF8"},
			{"id": "s1_p3", "scene_kind": "phasing", "speaker": "SCOUT MAYA", "dialogue": "Wait—Phantom Spirits are drifting STRAIGHT THROUGH the bunker wall!!", "narration": "Only spectral Spirits and winged infected ignore solid brick.", "sfx": "SHAAA...", "mood_color": "#C084FC"},
			{"id": "s1_p4", "scene_kind": "boss", "speaker": "CHIEF ROTJAW", "dialogue": "NO ONE LEAVES THIS VILLAGE ALIVE!!", "narration": "Boss Alert: Ground-slam shockwaves incoming on final wave.", "sfx": "DOOOM!!", "mood_color": "#EF4444"},
		],
	},
	2: {
		"badge": "CHAPTER 02 · GREEN QUARANTINE", "title": "Dark Forest", "subtitle": "Dense pines, mire bogs & prowling packs",
		"what_happened": [
			"Evacuation choppers went down over the pine canopy after an airborne blight spore cloud blanketed the ridge.",
			"Rangers fortified four woodland shelters, locking each checkpoint gate behind wave-synced laser barriers.",
			"Mire bogs slow foot speed outside cover while winged infected dive straight over timber roofs.",
		],
		"threat_note": "Use bunker hallways for cover against charging Brutes, and intercept Blight Wings hovering over partitions.",
		"boss_id": "forest_boss",
		"boss_summary": "Blightfang — Giant Infected Beast capable of high-speed ferocious charges across the clearing.",
		"accent_color": "#22C55E", "floor_color": "#264331",
		"manga_panels": [
			{"id": "s2_p1", "scene_kind": "crash", "speaker": "RANGER LEAD", "dialogue": "Evac bird went down in the spore fog! Regroup at Ranger Cabin!", "narration": "Deep canopy — toxic mist chokes the ridge.", "sfx": "WHOOOSH!!", "mood_color": "#22C55E"},
			{"id": "s2_p2", "scene_kind": "maya_snipe", "speaker": "SCOUT MAYA", "dialogue": "I have eyes from the Watchtower! Upgrade me when the pack thickens!", "narration": "Maya covers every clearing from elevated timber.", "sfx": "BLAM!!", "mood_color": "#F59E0B"},
			{"id": "s2_p3", "scene_kind": "phasing", "speaker": "RANGER LEAD", "dialogue": "Watch the roof! Blight Wings dive right past the bunker doors!", "narration": "Mire bogs drag your boots outside while flyers strike inside.", "sfx": "FLAP!!", "mood_color": "#34D399"},
			{"id": "s2_p4", "scene_kind": "boss", "speaker": "BLIGHTFANG", "dialogue": "GRRROOOAAAR!!", "narration": "Alpha Apex Beast detected charging toward the clearing!", "sfx": "RAAAWR!!", "mood_color": "#EF4444"},
		],
	},
	3: {
		"badge": "CHAPTER 03 · FALLEN METROPOLIS", "title": "Destroyed City", "subtitle": "Shattered boulevards & concrete barricades",
		"what_happened": [
			"Civil defense lines collapsed when armored riot units succumbed to the strain inside the downtown district.",
			"Only concrete subway checkpoints and the Citadel Tower remain powered behind active sector lockdown shields.",
			"Spitter Elites rain acid down the avenues while spectral Spirits phase straight through vault walls.",
		],
		"threat_note": "Sector barriers open only after clearing each wave. Fortify doorways with Barricades and Sentry Turrets.",
		"boss_id": "city_boss",
		"boss_summary": "Iron Bastion — Armored Warlord Zombie firing wide 5-bolt suppression barrages down the street.",
		"accent_color": "#F59E0B", "floor_color": "#374151",
		"manga_panels": [
			{"id": "s3_p1", "scene_kind": "squad_stand", "speaker": "RANGER LEAD", "dialogue": "Downtown fell overnight. Hold Subway Checkpoint at all costs!", "narration": "Concrete towers burn above shattered avenues.", "sfx": "BOOOOM!!", "mood_color": "#F59E0B"},
			{"id": "s3_p2", "scene_kind": "barricade", "speaker": "ARMORY TECH", "dialogue": "Stack barricades at the 84px doorways and bring turrets online!", "narration": "Coins drop from every zombie—fortify between waves.", "sfx": "ZAP-LOCK!", "mood_color": "#38BDF8"},
			{"id": "s3_p3", "scene_kind": "phasing", "speaker": "SCOUT MAYA", "dialogue": "Elites are melting the street, and Spirits are slipping through Bank Vault steel!", "narration": "Even armored vaults cannot stop wall-phasing Phantoms.", "sfx": "HISS!!", "mood_color": "#C084FC"},
			{"id": "s3_p4", "scene_kind": "boss", "speaker": "IRON BASTION", "dialogue": "SUPPRESSION BARRAGE—LOCKED ON TARGET.", "narration": "Armored Warlord approaching with 5-bolt heavy cannons!", "sfx": "KRAK-KRAK!!", "mood_color": "#EF4444"},
		],
	},
	4: {
		"badge": "CHAPTER 04 · CONTAINMENT BREACH", "title": "Research Facility", "subtitle": "Bio-containment floors & leaking chemical vats",
		"what_happened": [
			"Project Lazarus containment vats ruptured in Sub-Level 4, flooding corridors with mutagens and rogue test subjects.",
			"Automated airlock barriers partitioned the lab into five fortified bunkers to isolate the worst mutations.",
			"Chemical spills burn careless footsteps while Phantom Spirits emerge straight from the cryo chambers.",
		],
		"threat_note": "Stay clear of toxic vats and upgrade Scout Maya’s Watchtower early to shred armored lab horrors.",
		"boss_id": "laboratory_boss",
		"boss_summary": "Subject X-09 — Failed Experiment unleashing rapid toxic barrages and lethal melee lunges.",
		"accent_color": "#06B6D4", "floor_color": "#2B3A4A",
		"manga_panels": [
			{"id": "s4_p1", "scene_kind": "crash", "speaker": "LAB ALARM", "dialogue": "WARNING: Sub-Level 4 Lazarus Vats ruptured! Bio-lockdown active!", "narration": "Shattered glass echoes across five quarantined lab pods.", "sfx": "SHATTER!!", "mood_color": "#06B6D4"},
			{"id": "s4_p2", "scene_kind": "barricade", "speaker": "RANGER LEAD", "dialogue": "Watch your boots near the green vats—airlocks seal behind every wave!", "narration": "Five airlock bunkers stand between your squad and the lift.", "sfx": "BEEP-SEAL!", "mood_color": "#22C55E"},
			{"id": "s4_p3", "scene_kind": "phasing", "speaker": "SCOUT MAYA", "dialogue": "Cryo Spirits are phasing out of the reactor walls! Cover the interior!", "narration": "Phantom strains bypass concrete containment shields.", "sfx": "WAAAIL...", "mood_color": "#A855F7"},
			{"id": "s4_p4", "scene_kind": "boss", "speaker": "SUBJECT X-09", "dialogue": "EX-PER-I-MENT... UN-CHAINED!!", "narration": "Prototype Mutant lunges with rapid toxic volleys!", "sfx": "SPLASH-BAM!!", "mood_color": "#EF4444"},
		],
	},
	5: {
		"badge": "CHAPTER 05 · THE FINAL FRONT", "title": "The Deadlands", "subtitle": "Ash plains, obsidian spires & molten rifts",
		"what_happened": [
			"At the crater of Origin Rift, volcanic fissures and dark energy tore open the sky above the last military bastion.",
			"Five sequential vanguard bunkers form the final gauntlet leading to the Omega Extraction Citadel.",
			"Every mutated strain—and swarms of wall-phasing Spirits and Blight Wings—converges on your squad.",
		],
		"threat_note": "Clear all 5 waves, survive molten rifts, and defeat the Overlord before entering the Extraction Citadel.",
		"boss_id": "final_boss",
		"boss_summary": "Malakor Prime — Final Mutant Overlord combining devastating slams, charges, and fire barrages.",
		"accent_color": "#EF4444", "floor_color": "#3A2626",
		"manga_panels": [
			{"id": "s5_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "This is Origin Rift. One last push to the Omega Extraction Citadel!", "narration": "Crimson lightning splits the ash sky above five final bunkers.", "sfx": "KRAKOOM!!", "mood_color": "#EF4444"},
			{"id": "s5_p2", "scene_kind": "squad_stand", "speaker": "SCOUT MAYA", "dialogue": "Every skill, turret, and bullet counts now—no turning back!", "narration": "Teamwork, doorway traps, and full upgrades keep the line alive.", "sfx": "CLICK-CLACK!", "mood_color": "#F59E0B"},
			{"id": "s5_p3", "scene_kind": "phasing", "speaker": "RANGER LEAD", "dialogue": "Spirits and Blight Wings are swarming straight through the obsidian walls!", "narration": "Every undead strain converges at once.", "sfx": "SHRIEK!!", "mood_color": "#C084FC"},
			{"id": "s5_p4", "scene_kind": "boss", "speaker": "MALAKOR PRIME", "dialogue": "YOUR STORY ENDS IN ASH, RANGERS!!", "narration": "THE FINAL OVERLORD DESCENDS ON WAVE 5!", "sfx": "GOGOGOGO!!", "mood_color": "#EF4444"},
		],
	},
}

const HOME_INTRO_STORY: Dictionary = {
	"badge": "BEFORE THE OUTBREAK", "title": "The Last Antidote", "subtitle": "A Ranger Outbreak manga introduction", "accent_color": "#FBBF24",
	"manga_panels": [
		{"scene_kind": "origin_well", "speaker": "VILLAGE DOCTOR", "dialogue": "The convoy brought medicine. By dawn, our well was making people sick.", "narration": "A contaminated delivery reaches the first village before anyone knows the danger.", "sfx": "DRIP...", "mood_color": "#84CC16"},
		{"scene_kind": "origin_forest", "speaker": "SCOUT MAYA", "dialogue": "The forest spores are spreading. We have to reach the source.", "narration": "The infection follows roads, wind, and fleeing survivors into every sector.", "sfx": "WHOOOSH!", "mood_color": "#22C55E"},
		{"scene_kind": "hero_fight", "speaker": "RANGER LEAD", "dialogue": "Medic, cover my flank! Maya, keep the civilians moving!", "narration": "The Ranger and Medic fight together while Maya protects the evacuation line.", "sfx": "BLAM! ZAP!", "mood_color": "#F59E0B"},
		{"scene_kind": "antidote_pickup", "speaker": "FIELD SCIENTIST", "dialogue": "One prototype antidote survived. Find it at the village field clinic.", "narration": "Stage 1 begins the mission: retrieve the vial before the village is lost.", "sfx": "CLICK!", "mood_color": "#38BDF8"},
		{"scene_kind": "supply_run", "speaker": "RANGER LEAD", "dialogue": "Keep the vial safe. We will cross every bunker to reach Omega.", "narration": "Each stage has a task that opens the route toward the final extraction lab.", "sfx": "THUD-THUD!", "mood_color": "#A855F7"},
		{"scene_kind": "antidote_delivery", "speaker": "SCOUT MAYA", "dialogue": "Get it to the Deadlands lab. I'll stay with you until the end.", "narration": "At Stage 5, deliver the antidote and survive the last assault.", "sfx": "KRAKOOM!", "mood_color": "#EF4444"},
	],
}

const STAGE_ORIGIN_PANELS: Dictionary = {
	1: [
		{"scene_kind": "origin_well", "speaker": "VILLAGE DOCTOR", "dialogue": "Families drank from the square after the convoy passed. Then the fever began.", "narration": "The first patients were ordinary villagers before the outbreak took them.", "sfx": "DRIP...", "mood_color": "#84CC16"},
		{"scene_kind": "antidote_pickup", "speaker": "FIELD SCIENTIST", "dialogue": "I hid a prototype antidote in the field clinic. Please take it to Omega.", "narration": "Your Stage 1 task is to collect the vial before the final wave.", "sfx": "BEEP!", "mood_color": "#38BDF8"},
	],
	2: [
		{"scene_kind": "origin_forest", "speaker": "FOREST RANGER", "dialogue": "We opened the evacuation path. A green cloud rose from the wrecked chopper.", "narration": "Rescue crews inhaled blight spores while searching the pine ridge.", "sfx": "HISSS...", "mood_color": "#22C55E"},
		{"scene_kind": "origin_forest", "speaker": "SCOUT MAYA", "dialogue": "Their radios went silent one by one. We can still save whoever is left.", "narration": "The lost crew became the prowling packs beneath the canopy.", "sfx": "CRACK!", "mood_color": "#A3E635"},
	],
	3: [
		{"scene_kind": "origin_city", "speaker": "CITY MEDIC", "dialogue": "The hospital ran out of clean blood. We used emergency stock from the convoy.", "narration": "A contaminated transfusion carried the strain through the city wards.", "sfx": "BEEP...", "mood_color": "#F59E0B"},
		{"scene_kind": "origin_city", "speaker": "RANGER LEAD", "dialogue": "The armored responders were people protecting us yesterday.", "narration": "Riot shields and rescue uniforms remain on the infected downtown patrols.", "sfx": "KLANK!", "mood_color": "#EF4444"},
	],
	4: [
		{"scene_kind": "origin_lab", "speaker": "LAB TECH", "dialogue": "Lazarus was meant to reverse the fever. The test batch changed it instead.", "narration": "A failed treatment mutated patients inside sealed research chambers.", "sfx": "BEEP-ERR!", "mood_color": "#06B6D4"},
		{"scene_kind": "origin_lab", "speaker": "SCOUT MAYA", "dialogue": "Those hands on the glass belonged to the researchers. We keep moving.", "narration": "The lab staff were trapped with their own infected test subjects.", "sfx": "SHATTER!", "mood_color": "#A3E635"},
	],
	5: [
		{"scene_kind": "origin_rift", "speaker": "FIELD SCIENTIST", "dialogue": "The Rift amplified the strain. Omega can analyze the vial you carried here.", "narration": "The final outbreak began beneath the Deadlands extraction citadel.", "sfx": "VWOOM!", "mood_color": "#EF4444"},
		{"scene_kind": "antidote_delivery", "speaker": "RANGER LEAD", "dialogue": "Deliver the antidote before the last wave. Then we face Malakor.", "narration": "Your Stage 5 task completes the route begun in the village.", "sfx": "CLACK!", "mood_color": "#38BDF8"},
	],
}

const MAYA_INFECTION_STORY: Dictionary = {
	"badge": "AFTER THE BATTLE",
	"title": "Maya's Last Stand",
	"accent_color": "#BEF264",
	"manga_panels": [
		{
			"scene_kind": "maya_cover",
			"speaker": "SCOUT MAYA",
			"dialogue": "It's down. I'll check the body.",
			"narration": "Maya leaves her watchtower and approaches the fallen guardian.",
			"sfx": "STEP...",
			"mood_color": "#FBBF24",
		},
		{
			"scene_kind": "maya_wounded",
			"speaker": "SCOUT MAYA",
			"dialogue": "Its hand... it won't let go!",
			"narration": "The guardian's hand closes around Maya's arm and tears through her sleeve.",
			"sfx": "RRRIP!",
			"mood_color": "#F87171",
		},
		{
			"scene_kind": "maya_turning",
			"speaker": "SCOUT MAYA",
			"dialogue": "Get back! The bodies are moving!",
			"narration": "The infection takes hold as Maya drags the guardian into a heap of fallen infected.",
			"sfx": "THUD... THUD...",
			"mood_color": "#A3E635",
		},
		{
			"scene_kind": "maya_infected",
			"speaker": "INFECTED MAYA",
			"dialogue": "Run...",
			"narration": "The dead fuse around Maya and roll toward the squad as the Human Tumbleweed.",
			"sfx": "RRRUMBLE!",
			"mood_color": "#BEF264",
		},
	],
}

const MAYA_ANTIDOTE_FINALE: Dictionary = {
	"badge": "AFTER THE BATTLE",
	"title": "One More Breath",
	"accent_color": "#5EEAD4",
	"manga_panels": [
		{
			"scene_kind": "maya_antidote_approach",
			"dialogue": "Maya! Stay with me.",
			"narration": "The Human Tumbleweed breaks apart. Maya lies among the fallen.",
			"sfx": "THUD.",
			"mood_color": "#BEF264",
		},
		{
			"scene_kind": "maya_antidote_injection",
			"dialogue": "I've got you.",
			"narration": "The fighter who landed the final blow injects the antidote into Maya's neck.",
			"sfx": "CLICK.",
			"mood_color": "#67E8F9",
		},
		{
			"scene_kind": "maya_antidote_recovery",
			"speaker": "SCOUT MAYA",
			"dialogue": "I can breathe again.",
			"narration": "The camera pulls back as the color returns to Maya's face.",
			"sfx": "HAAH...",
			"mood_color": "#FDE68A",
		},
	],
}

const ENDLESS_REALM_STORIES: Array[Dictionary] = [
	{
		"boss_id": "village_boss",
		"what_happened": [
			"Dimensional rift telemetry dumped your squad into the Shattered Outpost—a fractured echo of the first quarantine line.",
			"Automated bunker barriers lock all secondary shelters until each wave is cleared from the active relay.",
			"Defeat 10 escalating waves to tear open the next Dimensional Portal—only your upgraded skills travel through!",
		],
		"boss_summary": "Chief Rotjaw Echo — Leads Wave 10 hordes with seismic slams guarding the Portal.",
		"manga_panels": [
			{"id": "e1_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "A Dimensional Rift opened right over Shattered Outpost!", "narration": "REALM 1 — Endless temporal anomalies surge every wave.", "sfx": "VWOOOM!!", "mood_color": "#F59E0B"},
			{"id": "e1_p2", "scene_kind": "barricade", "speaker": "SCOUT MAYA", "dialogue": "Secondary bunkers are shield-locked—defend our active compound!", "narration": "Buy skill charges each wave before hordes breach the doors.", "sfx": "LOCK-ON!", "mood_color": "#38BDF8"},
			{"id": "e1_p3", "scene_kind": "phasing", "speaker": "RANGER LEAD", "dialogue": "Survive 10 waves and the Portal Gate will rip open—keep walls tight!", "narration": "Spirits still slip past brick walls; turrets guard the core.", "sfx": "SHAAA...", "mood_color": "#C084FC"},
			{"id": "e1_p4", "scene_kind": "boss", "speaker": "ROTJAW ECHO", "dialogue": "FACE THE RIFT GUARDIAN!!", "narration": "Wave 10 Boss guards the Portal Leap!", "sfx": "SMAAASH!!", "mood_color": "#EF4444"},
		],
	},
	{
		"boss_id": "forest_boss",
		"what_happened": [
			"The Dimensional Portal dropped you into the Toxic Wasteland where acid marshes dissolved every prior barricade.",
			"Old turrets and walls could not survive the jump, yet your surged Skills burn hotter than ever.",
			"Watch the bunker doorways—Phantom Spirits and Blight Wings ignore concrete walls completely.",
		],
		"boss_summary": "Blightfang Apex — Stalks the acid wastes with amplified charge velocity on milestone waves.",
		"manga_panels": [
			{"id": "e2_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "Our old barricades dissolved in the jump—but our Skills just SURGED!", "narration": "PORTAL WARP — Builds reset, Skill Power +35% stronger!", "sfx": "ZAAAP!!", "mood_color": "#22C55E"},
			{"id": "e2_p2", "scene_kind": "barricade", "speaker": "RANGER LEAD", "dialogue": "Rebuild traps fast! Acid pools guard the south flank!", "narration": "Fresh fortifications rise inside the Toxic Wasteland.", "sfx": "CLANK!!", "mood_color": "#F59E0B"},
			{"id": "e2_p3", "scene_kind": "phasing", "speaker": "SQUAD RADIO", "dialogue": "Winged swarms are banking straight over the compound roof!", "narration": "Upgraded abilities cut down wall-phasing raiders.", "sfx": "SWOOOSH!", "mood_color": "#34D399"},
			{"id": "e2_p4", "scene_kind": "boss", "speaker": "BLIGHTFANG APEX", "dialogue": "HUNT NEVER ENDS!!", "narration": "Hyper-charged Apex Beast hunts the portal zone.", "sfx": "ROOOAR!!", "mood_color": "#EF4444"},
		],
	},
	{
		"boss_id": "city_boss",
		"what_happened": [
			"Static lightning crackles across Cyber Ruins, an abandoned grid powered by unstable relay cores.",
			"Bunker shields keep surrounding vaults sealed until the current sector is purged of infected.",
			"Upgrade skills and rebuild turrets between waves as elites and spectral swarms tighten the noose.",
		],
		"boss_summary": "Iron Bastion MK-II — Blankets ruined intersections in heavy armored cannon fire.",
		"manga_panels": [
			{"id": "e3_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "Cyber Ruins grid is live—lightning arcs straight off the pylons!", "narration": "PORTAL LEAP — Skills surge even higher to match cyber hordes.", "sfx": "BZZZT!!", "mood_color": "#38BDF8"},
			{"id": "e3_p2", "scene_kind": "squad_stand", "speaker": "RANGER LEAD", "dialogue": "Our weapons are calibrated—let us hold the central nexus!", "narration": "Upgrade weapons and Skill ranks to shred elite armor.", "sfx": "PING-FIRE!", "mood_color": "#0EA5E9"},
			{"id": "e3_p3", "scene_kind": "phasing", "speaker": "RANGER LEAD", "dialogue": "Phantom Spirits are emerging straight out of the data walls!", "narration": "Keep ammo stocked and dash ready for crossfire.", "sfx": "GLITCH!!", "mood_color": "#C084FC"},
			{"id": "e3_p4", "scene_kind": "boss", "speaker": "IRON BASTION MK-II", "dialogue": "FULL VOLLEY PROTOCOL ENGAGED.", "narration": "Armored Warlord MK-II locks onto the bunker.", "sfx": "BRRRRT!!", "mood_color": "#EF4444"},
		],
	},
	{
		"boss_id": "laboratory_boss",
		"what_happened": [
			"Volcanic fissures split the Crimson Rift beneath molten skystorms—former fortifications turned to ash in transit.",
			"Every step outside solid bunker walls risks ambushes from fast sprinters and soaring Blight Wings.",
			"Hold out for 10 more waves until the dimensional rift stabilizes for the next portal leap.",
		],
		"boss_summary": "Subject X-09 Omega — Unleashes high-damage bio-barrages across the volcanic rift.",
		"manga_panels": [
			{"id": "e4_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "Lava fissures everywhere! Nothing survived transit except our Skills!", "narration": "CRIMSON RIFT — Heat distortion shakes every bunker.", "sfx": "FWOOSH!!", "mood_color": "#EF4444"},
			{"id": "e4_p2", "scene_kind": "barricade", "speaker": "RANGER LEAD", "dialogue": "Lock the doorways and stack fresh turrets before the sprinters hit!", "narration": "Only solid tactics survive 10 volcanic waves.", "sfx": "THUD-THUD!", "mood_color": "#F59E0B"},
			{"id": "e4_p3", "scene_kind": "phasing", "speaker": "SQUAD RADIO", "dialogue": "Ash Spirits are passing right through the masonry—watch your six!", "narration": "Close-quarters combat erupts inside the living quarters.", "sfx": "SHRIEK!!", "mood_color": "#C084FC"},
			{"id": "e4_p4", "scene_kind": "boss", "speaker": "SUBJECT X-09 OMEGA", "dialogue": "MELTDOWN IMMINENT!!", "narration": "Omega Specimen charges across molten rifts!", "sfx": "KRA-BOOM!!", "mood_color": "#EF4444"},
		],
	},
	{
		"boss_id": "final_boss",
		"what_happened": [
			"Welcome to the Astral Citadel—the deepest distortion zone where void conduits amplify both monster and Ranger power.",
			"Only your honed skills carried across portals; rebuild traps fresh at the bunker shop between waves.",
			"Survive relentless ground assaults and wall-phasing Spirits to claim endless leaderboard glory.",
		],
		"boss_summary": "Malakor Prime Ascendant — Supreme rift overlord commanding full-arena slams and barrages.",
		"manga_panels": [
			{"id": "e5_p1", "scene_kind": "portal", "speaker": "RANGER LEAD", "dialogue": "Astral Citadel... the deepest layer of the Rift!", "narration": "FINAL REALM — Void energy amplifies every strike.", "sfx": "SHINGGG!!", "mood_color": "#A855F7"},
			{"id": "e5_p2", "scene_kind": "squad_stand", "speaker": "RANGER LEAD", "dialogue": "All skills maxed out—let us show the horde what this squad is made of!", "narration": "The squad brings its full arsenal to bear.", "sfx": "OVERDRIVE!", "mood_color": "#F59E0B"},
			{"id": "e5_p3", "scene_kind": "phasing", "speaker": "RANGER LEAD", "dialogue": "Void Spirits pouring through all four walls—hold the center room!", "narration": "Unrelenting swarms test every doorway trap.", "sfx": "VOOOOM!!", "mood_color": "#C084FC"},
			{"id": "e5_p4", "scene_kind": "boss", "speaker": "MALAKOR ASCENDANT", "dialogue": "CHALLENGE ETERNITY, MORTALS!!", "narration": "ASCENDANT OVERLORD JOINS THE ENDLESS STORM!", "sfx": "GOGOGOGO!!", "mood_color": "#EF4444"},
		],
	},
]

const TUTORIAL_STEPS: Array[String] = [
	"Step 1/9: Move your hero with the movement controls.",
	"Step 2/9: Select a zombie to lock on, or use Attack to aim at the nearest one.",
	"Step 3/9: Keep firing your primary weapon at incoming zombies!",
	"Step 4/9: Use Reload with a pistol, or activate a skill as the Medic.",
	"Step 5/9: Activate a power skill.",
	"Step 6/9: Zombie kills grant Coins and Points automatically. Walk over Medkits to heal.",
	"Step 7/9: Defeat the incoming zombie squad, then move forward into the Safe Bunker!",
	"Step 8/9: Boss Battle! Defeat Chief Rotjaw Jr. and enter the Safe Bunker.",
	"Step 9/9: Training Complete! Bonus Survival Points awarded.",
]

const LANGUAGE_LABELS: Dictionary = {
	"en": "English",
	"es": "Español",
	"fil": "Filipino",
}

const TRANSLATIONS: Dictionary = {
	"en": {
		"gameTitle": "Zombie Apocalypse",
		"splashSubtitle": "Top-down blocky Ranger survival across 5 infected worlds, endless waves, and online co-op.",
		"enterHub": "Enter Command Hub",
		"pressContinue": "Press Enter or Space to continue",
		"armory": "Armory",
		"chatFriends": "Chat & Friends",
		"leaderboards": "Leaderboards",
		"howToPlay": "How to Play",
		"account": "Account",
		"signIn": "Sign In",
		"playOffline": "Play Offline",
		"playOnline": "Play Online Co-op",
		"storyMode": "Story Mode (5 Stages)",
		"endlessMode": "Endless Survival",
		"deployStage": "Deploy to Stage",
		"startEndless": "Start Endless Survival",
		"findCoop": "Find Co-op Squad / Private Room",
		"totalStars": "Total Stars",
		"requiresStars": "Needs",
		"cleared": "Cleared",
		"waves": "Waves",
		"settingsTitle": "Settings & Accessibility",
		"muteAudio": "Mute Audio",
		"masterVolume": "Master Volume",
		"vibration": "Controller Vibration (Haptics)",
		"screenShake": "Camera Screen Shake",
		"dayNight": "Dynamic Day/Night Lighting",
		"damageNumbers": "Floating Damage Numbers",
		"languageLabel": "Language",
		"colorBlindLabel": "Color-Blind Palette",
		"textSizeLabel": "Text Size",
		"resetSave": "Reset Local Offline Save",
		"done": "Done",
		"missionPaused": "Mission Paused",
		"resumeMission": "Resume Mission",
		"restartStage": "Restart Stage",
		"returnLobby": "Return to Lobby",
		"missionAccomplished": "Mission Accomplished",
		"campaignComplete": "Campaign Complete!",
		"squadWipedOut": "Squad Wiped Out",
		"playAgain": "Play Again",
		"tryAgain": "Try Again",
		"nextStage": "Next Stage",
		"backToLobby": "Back to Lobby",
		"offlineBanner": "Offline Mode — Playing with local device save",
		"serverUnreachable": "Multiplayer server unreachable. Check Wi-Fi or switch to Offline Mode.",
		"switchOffline": "Switch to Offline Mode",
		"bunkerSafe": "Safe inside",
		"deployNextWave": "Deploy Next Wave",
		"shop": "Shop [B]",
		"chat": "Chat",
		"attack": "Attack",
	},
	"es": {
		"gameTitle": "Apocalipsis Zombi",
		"splashSubtitle": "Supervivencia táctica en 5 mundos infectados, oleadas infinitas y cooperativo en línea.",
		"enterHub": "Entrar al Cuartel",
		"pressContinue": "Pulsa Enter o Espacio para continuar",
		"armory": "Armería",
		"chatFriends": "Chat y Amigos",
		"leaderboards": "Clasificación",
		"howToPlay": "Tutorial",
		"account": "Cuenta",
		"signIn": "Iniciar Sesión",
		"playOffline": "Jugar Sin Conexión",
		"playOnline": "Cooperativo Online",
		"storyMode": "Modo Historia (5 Niveles)",
		"endlessMode": "Supervivencia Infinita",
		"deployStage": "Desplegar al Nivel",
		"startEndless": "Iniciar Modo Infinito",
		"findCoop": "Buscar Escuadrón / Sala Privada",
		"totalStars": "Estrellas Totales",
		"requiresStars": "Requiere",
		"cleared": "Completado",
		"waves": "Oleadas",
		"settingsTitle": "Ajustes y Accesibilidad",
		"muteAudio": "Silenciar Audio",
		"masterVolume": "Volumen Maestro",
		"vibration": "Vibración Táctil",
		"screenShake": "Sacudida de Cámara",
		"dayNight": "Iluminación Día/Noche",
		"damageNumbers": "Números de Daño",
		"languageLabel": "Idioma",
		"colorBlindLabel": "Paleta para Daltonismo",
		"textSizeLabel": "Tamaño de Texto",
		"resetSave": "Reiniciar Guardado Local",
		"done": "Listo",
		"missionPaused": "Misión en Pausa",
		"resumeMission": "Reanudar Misión",
		"restartStage": "Reiniciar Nivel",
		"returnLobby": "Volver al Cuartel",
		"missionAccomplished": "¡Misión Cumplida!",
		"campaignComplete": "¡Campaña Completada!",
		"squadWipedOut": "Escuadrón Caído",
		"playAgain": "Jugar de Nuevo",
		"tryAgain": "Reintentar",
		"nextStage": "Siguiente Nivel",
		"backToLobby": "Volver al Cuartel",
		"offlineBanner": "Modo Sin Conexión — Guardado local activo",
		"serverUnreachable": "Servidor multijugador inaccesible. Revisa tu Wi-Fi o cambia a Modo Offline.",
		"switchOffline": "Cambiar a Modo Offline",
		"bunkerSafe": "A salvo en",
		"deployNextWave": "Siguiente Oleada",
		"shop": "Tienda [B]",
		"chat": "Chat",
		"attack": "Atacar",
	},
	"fil": {
		"gameTitle": "Zombie Apocalypse",
		"splashSubtitle": "Top-down survival sa 5 mundong may impeksyon, walang-hanggang wave, at online co-op.",
		"enterHub": "Pumasok sa Command Hub",
		"pressContinue": "Pindutin ang Enter o Space para magpatuloy",
		"armory": "Armory",
		"chatFriends": "Chat at Kaibigan",
		"leaderboards": "Leaderboard",
		"howToPlay": "Paano Maglaro",
		"account": "Account",
		"signIn": "Mag-Sign In",
		"playOffline": "Maglaro Offline",
		"playOnline": "Online Co-op",
		"storyMode": "Story Mode (5 Antas)",
		"endlessMode": "Endless Survival",
		"deployStage": "Sumabak sa Antas",
		"startEndless": "Simulan ang Endless",
		"findCoop": "Maghanap ng Squad / Private Room",
		"totalStars": "Kabuuang Bituin",
		"requiresStars": "Kailangan",
		"cleared": "Tapos na",
		"waves": "Mga Wave",
		"settingsTitle": "Mga Setting at Accessibility",
		"muteAudio": "I-mute ang Tunog",
		"masterVolume": "Lakas ng Tunog",
		"vibration": "Vibration ng Controller",
		"screenShake": "Pag-alog ng Camera",
		"dayNight": "Ilaw ng Araw at Gabi",
		"damageNumbers": "Numero ng Damage",
		"languageLabel": "Wika (Language)",
		"colorBlindLabel": "Palette para sa Color-Blind",
		"textSizeLabel": "Laki ng Teksto",
		"resetSave": "I-reset ang Lokal na Save",
		"done": "Tapos na",
		"missionPaused": "Naka-Pause ang Misyon",
		"resumeMission": "Ipagpatuloy",
		"restartStage": "Ulitin ang Antas",
		"returnLobby": "Bumalik sa Lobby",
		"missionAccomplished": "Tagumpay ang Misyon!",
		"campaignComplete": "Tapos ang Buong Kampanya!",
		"squadWipedOut": "Natalo ang Squad",
		"playAgain": "Maglaro Muli",
		"tryAgain": "Subukan Muli",
		"nextStage": "Susunod na Antas",
		"backToLobby": "Bumalik sa Lobby",
		"offlineBanner": "Offline Mode — Lokal na save sa device ang gamit",
		"serverUnreachable": "Hindi maabot ang online server. Suriin ang Wi-Fi o mag-Offline Mode.",
		"switchOffline": "Lumipat sa Offline Mode",
		"bunkerSafe": "Ligtas sa loob ng",
		"deployNextWave": "Susunod na Wave",
		"shop": "Tindahan [B]",
		"chat": "Chat",
		"attack": "Atake",
	},
}


func t(lang: String, key: String) -> String:
	var lang_dict: Dictionary = TRANSLATIONS.get(lang, TRANSLATIONS["en"])
	if lang_dict.has(key):
		return str(lang_dict[key])
	return str(TRANSLATIONS["en"].get(key, key))


func get_endless_portal_theme(realm_number: int) -> Dictionary:
	var idx := (maxi(1, realm_number) - 1) % ENDLESS_PORTAL_REALMS.size()
	var theme := ENDLESS_PORTAL_REALMS[idx].duplicate(true)
	theme["realm_number"] = maxi(1, realm_number)
	return theme


func get_stage_by_id(stage_id: int, portal_realm: int = 1) -> Dictionary:
	if stage_id == 99:
		var arena := ENDLESS_ARENA.duplicate(true)
		var theme := get_endless_portal_theme(portal_realm)
		arena["name"] = theme["name"]
		arena["subtitle"] = theme["subtitle"]
		arena["floor_color"] = theme["floor_color"]
		arena["floor_grid_color"] = theme["floor_grid_color"]
		arena["accent_color"] = theme["accent_color"]
		arena["obstacles"] = theme["obstacles"].duplicate(true)
		return _expand_arena(arena)
	for s in STAGES:
		if int(s["id"]) == stage_id:
			return _expand_arena(s.duplicate(true))
	return _expand_arena(STAGES[0].duplicate(true))


func _expand_arena(arena: Dictionary) -> Dictionary:
	# Space the bunkers farther apart while keeping their rooms and doorways the same size.
	const X_SCALE := 1.40
	const Y_SCALE := 1.22
	arena["map_width"] = float(arena["map_width"]) * X_SCALE
	arena["map_height"] = float(arena["map_height"]) * Y_SCALE
	for group in ["bunkers", "obstacles", "lanterns"]:
		for item in arena.get(group, []):
			item["x"] = float(item["x"]) * X_SCALE
			item["y"] = float(item["y"]) * Y_SCALE
	return arena


func resolve_nakama_url(url: String) -> String:
	var cleaned := url.strip_edges().rstrip("/")
	return NAKAMA_SERVER_URL if cleaned.is_empty() or cleaned in RETIRED_NAKAMA_URLS else cleaned


func get_maya_infection_story() -> Dictionary:
	return MAYA_INFECTION_STORY.duplicate(true)


func get_maya_antidote_finale(finisher_name: String, finisher_class: String, squad: Array) -> Dictionary:
	var story := MAYA_ANTIDOTE_FINALE.duplicate(true)
	var speaker := finisher_name.strip_edges()
	if speaker.is_empty():
		speaker = finisher_class.capitalize() if not finisher_class.is_empty() else "Ranger"
	var panels: Array = story["manga_panels"]
	for panel in panels:
		panel["finisher_class"] = finisher_class
		if not panel.has("speaker"):
			panel["speaker"] = speaker.to_upper()
	panels.back()["squad"] = squad.duplicate(true)
	if not squad.is_empty():
		panels.back()["narration"] = "The squad gathers behind Maya as she takes her first clear breath."
	return story


func get_home_intro_story() -> Dictionary:
	return HOME_INTRO_STORY.duplicate(true)


func get_story_briefing(mode: String, stage_id: int, portal_realm: int = 1) -> Dictionary:
	if mode == "tutorial":
		return {}
	if mode == "story":
		var ch: Dictionary = STORY_CHAPTERS.get(stage_id, STORY_CHAPTERS[1]).duplicate(true)
		ch["key"] = "story_%d" % stage_id
		ch["manga_panels"] = STAGE_ORIGIN_PANELS.get(stage_id, []).duplicate(true) + ch["manga_panels"]
		return ch
	var realm := maxi(1, portal_realm)
	var theme := get_endless_portal_theme(realm)
	var narrative: Dictionary = ENDLESS_REALM_STORIES[(realm - 1) % ENDLESS_REALM_STORIES.size()].duplicate(true)
	var threat_note := ""
	if realm > 1:
		threat_note = "Portal Warp Complete! Previous builds reset, while all Skills surged +%d%% power. Spirits & Flyers still phase through walls!" % ((realm - 1) * 35)
	else:
		threat_note = "Locked bunkers stay sealed until their wave activates. Bunker walls stop walkers, but Spirits & Flyers pass right through!"
	return {
		"key": "endless_realm_%d" % realm,
		"badge": "ENDLESS ARC · REALM %d" % realm,
		"title": theme["name"],
		"subtitle": theme["subtitle"],
		"what_happened": narrative["what_happened"],
		"threat_note": threat_note,
		"boss_id": narrative["boss_id"],
		"boss_summary": narrative["boss_summary"],
		"accent_color": theme["accent_color"],
		"floor_color": theme["floor_color"],
		"manga_panels": narrative["manga_panels"],
	}
