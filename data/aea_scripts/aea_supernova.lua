local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end
local function get_velocity_vector(speed, angle)
	return {
		x = speed * math.cos(angle),
		y = speed * math.sin(angle)
	}
end
local function get_position_offset_angle(pos, angle, offset)
	local cos_a = math.cos(math.rad(angle))
	local sin_a = math.sin(math.rad(angle))

	local relative_offset_x = offset.x * cos_a - offset.y * sin_a
	local relative_offset_y = offset.x * sin_a + offset.y * cos_a

	return {x = pos.x + relative_offset_x, y = pos.y + relative_offset_y}
end
local function get_mag(v)
	return math.sqrt(v.x * v.x + v.y * v.y)
end
local function normalize(v)
	local magnitude = get_mag(v)
	if magnitude > 0 then
		return {
			x = v.x / magnitude,
			y = v.y / magnitude,
		}
	else
		return {x = 0, y = 0}
	end
end
local function sub_vectors(a, b)
	return {
		x = a.x - b.x,
		y = a.y - b.y,
	}
end
local function add_vectors(a, b)
	return {
		x = a.x + b.x,
		y = a.y + b.y,
	}
end
local function scale_vector(v, s)
	return {
		x = v.x * s,
		y = v.y * s,
	}
end
local function normalize_angle(angle)
	angle = angle % 360
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end
local function angle_diff(angle1, angle2)
	local diff = angle2 - angle1
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return diff
end
local function get_angle_between_points(pos, target_pos)
	local alpha = math.atan((target_pos.y-pos.y), (target_pos.x-pos.x))
	return normalize_angle(math.deg(alpha))
end
local function move_angle_to(current_angle, target_angle, max_rotation)
	local diff = target_angle - current_angle
	if diff > 180 then
		diff = diff - 360
	elseif diff <= -180 then
		diff = diff + 360
	end

	local new_angle

	if math.abs(diff) <= math.abs(max_rotation) then
		new_angle = target_angle
	else
		if diff > 0 then
			new_angle = current_angle + math.abs(max_rotation)
		else
			new_angle = current_angle - math.abs(max_rotation)
		end
	end
	return normalize_angle(new_angle)
end

local source_types = {player = 1, enemy = 2, world = 3}
local aim_types = {player = 1, player_ahead = 2, enemy = 3, world = 4}
local projectile_types = {laser = 1, mine = 2, beam  = 3}
local colour_base = Graphics.GL_Color(1, 1, 1, 1)

--PROJECTILES--
local player_laser_light = {
	type = projectile_types.laser,
	speed = 800,
	collider_radius = 3,
	damage = 10,
	firing_sound = "laser_light",
	hit_sound = "hitHull2",
	image = Hyperspace.Resources:CreateImagePrimitiveString("projectiles/laser_stun.png", -30, -10, 0, colour_base, 1, false),
}
player_laser_light.image.textureAntialias = true
local player_flak_small = {
	type = projectile_types.laser,
	speed = 600,
	spin = 720,
	collider_radius = 5,
	damage = 10,
	firing_sound = "flak",
	hit_sound = "flakImpact1",
	image = Hyperspace.Resources:CreateImagePrimitiveString("projectiles/flak_aea_supernova.png", -8, -8, 0, colour_base, 1, false),
}
player_flak_small.image.textureAntialias = true
local player_missile_small = {
	type = projectile_types.laser,
	speed = 400,
	collider_radius = 5,
	home_time = 60,
	damage = 40,
	firing_sound = "smallMissile1",
	hit_sound = "smallExplosion",
	image = Hyperspace.Resources:CreateImagePrimitiveString("weapons/missile_burst.png", -22, -16, 0, colour_base, 1, false),
}
player_missile_small.image.textureAntialias = true
local player_beam_small = {
	type = projectile_types.beam,
	collider_radius = 5,
	damage = 2,
	firing_sound = "beam1",
	hit_sound = "beam2",
	colour = Graphics.GL_Color(0.8, 0.7, 0, 0.5),
}
local player_bomb_small = {
	type = projectile_types.laser,
	trigger_radius = 45,
	trigger_time = 0.5,
	explosion_image_name = "explosion_big2",
	explsion_sound = "smallExplosion",
	damage = 50,
	firing_sound = "bombTeleport",
	hit_sound = "smallExplosion",
	image = Hyperspace.Resources:CreateImagePrimitiveString("projectiles/bomb_aea_supernova.png", -16, -16, 0, colour_base, 1, false),
}
player_bomb_small.image.textureAntialias = true

local laser_heavy = {
	type = projectile_types.laser,
	speed = 300,
	collider_radius = 5,
	damage = 15,
	firing_sound = "heavyLaser1",
	hit_sound = "hitHull1",
	image = Hyperspace.Resources:CreateImagePrimitiveString("projectiles/laser_heavy_base.png", -30, -10, 0, colour_base, 1, false),
}
laser_heavy.image.textureAntialias = true
local laser_light = {
	type = projectile_types.laser,
	speed = 600,
	collider_radius = 3,
	damage = 10,
	firing_sound = "laser_light",
	hit_sound = "hitHull2",
	image = Hyperspace.Resources:CreateImagePrimitiveString("projectiles/laser_light.png", -30, -10, 0, colour_base, 1, false),
}
laser_light.image.textureAntialias = true
local laser_light_projection = {
	type = projectile_types.beam,
	collider_radius = 5,
	damage = 0,
	follow_up = laser_light,
	colour = Graphics.GL_Color(0.8, 0.5, 0.1, 0.25),
}
local mine_small = {
	type = projectile_types.mine,
	trigger_radius = 40,
	trigger_time = 1,
	explosion_image_name = "explosion_random",
	explosion_sound = "smallExplosion",
	damage = 25,
	firing_sound = "smallMissile1",
	hit_sound = "smallExplosion",
	image = Hyperspace.Resources:CreateImagePrimitiveString("mines/mine_small.png", -11, -11, 0, colour_base, 1, false),
}
mine_small.image.textureAntialias = true
local beam_small = {
	type = projectile_types.beam,
	collider_radius = 12,
	damage = 25,
	firing_sound = "beam1",
	hit_sound = "beam2",
	colour = Graphics.GL_Color(1, 0.1, 0.1, 0.5),
}
local beam_small_projection = {
	type = projectile_types.beam,
	collider_radius = 8,
	damage = 0,
	follow_up = beam_small,
	colour = Graphics.GL_Color(0.8, 0.5, 0.1, 0.25),
}
--INSTANTANEOUS ATTACKS--
local attack_shotgun = {
	projectiles = {
		{template = laser_light, angle_offset = -5, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_light, angle_offset = -2.5, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_light, angle_offset = -0, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_light, angle_offset = 2.5, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_light, angle_offset = 5, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_beam = {
	projectiles = {
		{template = beam_small, angle_offset = 0, pos_offset = {x = 0, y = 0}, life_time = 5, track = true},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_beam_short = {
	projectiles = {
		{template = beam_small, angle_offset = 0, pos_offset = {x = 0, y = 0}, life_time = 3.5, track = true},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_beam_pinpoint = {
	projectiles = {
		{template = beam_small, angle_offset = 0, pos_offset = {x = 0, y = 0}, life_time = 1, track = true},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_beam_projected = {
	projectiles = {
		{template = beam_small_projection, angle_offset = 0, pos_offset = {x = 0, y = 0}, life_time = 1},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_beam_grid_hori = {
	projectiles = {
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = -450}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = -300}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = -150}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = 0}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = 150}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = 300}, life_time = 1},
		{template = beam_small_projection, angle_offset = 180, pos_offset = {x = 1000, y = 450}, life_time = 1},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_beam_grid_vert = {
	projectiles = {
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = -450, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = -300, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = -150, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = 0, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = 150, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = 300, y = -600}, life_time = 1},
		{template = beam_small_projection, angle_offset = 90, pos_offset = {x = 450, y = -600}, life_time = 1},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_star_quad = {
	projectiles = {
		{template = laser_heavy, angle_offset = 0, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = 90, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = 180, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = -90, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_mine_drop = {
	projectiles = {
		{template = mine_small, angle_offset = 0, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_laser_arc_up = {
	projectiles = {
		{template = laser_light_projection, angle_offset = 135, pos_offset = {x = 350, y = -350}, life_time = 1},
		{template = laser_light_projection, angle_offset = 126, pos_offset = {x = 280, y = -350}, life_time = 1.1},
		{template = laser_light_projection, angle_offset = 117, pos_offset = {x = 210, y = -350}, life_time = 1.2},
		{template = laser_light_projection, angle_offset = 108, pos_offset = {x = 140, y = -350}, life_time = 1.3},
		{template = laser_light_projection, angle_offset = 99, pos_offset = {x = 70, y = -350}, life_time = 1.4},
		{template = laser_light_projection, angle_offset = 90, pos_offset = {x = 0, y = -350}, life_time = 1.5},
		{template = laser_light_projection, angle_offset = 81, pos_offset = {x = -70, y = -350}, life_time = 1.6},
		{template = laser_light_projection, angle_offset = 72, pos_offset = {x = -140, y = -350}, life_time = 1.7},
		{template = laser_light_projection, angle_offset = 63, pos_offset = {x = -210, y = -350}, life_time = 1.8},
		{template = laser_light_projection, angle_offset = 54, pos_offset = {x = -280, y = -350}, life_time = 1.9},
		{template = laser_light_projection, angle_offset = 45, pos_offset = {x = -350, y = -350}, life_time = 2},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_laser_arc_down = {
	projectiles = {
		{template = laser_light_projection, angle_offset = -45, pos_offset = {x = -350, y = 350}, life_time = 1},
		{template = laser_light_projection, angle_offset = -54, pos_offset = {x = -280, y = 350}, life_time = 1.1},
		{template = laser_light_projection, angle_offset = -63, pos_offset = {x = -210, y = 350}, life_time = 1.2},
		{template = laser_light_projection, angle_offset = -72, pos_offset = {x = -140, y = 350}, life_time = 1.3},
		{template = laser_light_projection, angle_offset = -81, pos_offset = {x = -70, y = 350}, life_time = 1.4},
		{template = laser_light_projection, angle_offset = -90, pos_offset = {x = 0, y = 350}, life_time = 1.5},
		{template = laser_light_projection, angle_offset = -99, pos_offset = {x = 70, y = 350}, life_time = 1.6},
		{template = laser_light_projection, angle_offset = -108, pos_offset = {x = 140, y = 350}, life_time = 1.7},
		{template = laser_light_projection, angle_offset = -117, pos_offset = {x = 210, y = 350}, life_time = 1.8},
		{template = laser_light_projection, angle_offset = -126, pos_offset = {x = 280, y = 350}, life_time = 1.9},
		{template = laser_light_projection, angle_offset = -135, pos_offset = {x = 350, y = 350}, life_time = 2},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_laser_arc_left = {
	projectiles = {
		{template = laser_light_projection, angle_offset = 45, pos_offset = {x = -350, y = -350}, life_time = 1},
		{template = laser_light_projection, angle_offset = 36, pos_offset = {x = -350, y = -280}, life_time = 1.1},
		{template = laser_light_projection, angle_offset = 27, pos_offset = {x = -350, y = -210}, life_time = 1.2},
		{template = laser_light_projection, angle_offset = 18, pos_offset = {x = -350, y = -140}, life_time = 1.3},
		{template = laser_light_projection, angle_offset = 9, pos_offset = {x = -350, y = -70}, life_time = 1.4},
		{template = laser_light_projection, angle_offset = 0, pos_offset = {x = -350, y = 0}, life_time = 1.5},
		{template = laser_light_projection, angle_offset = -9, pos_offset = {x = -350, y = 70}, life_time = 1.6},
		{template = laser_light_projection, angle_offset = -18, pos_offset = {x = -350, y = 140}, life_time = 1.7},
		{template = laser_light_projection, angle_offset = -27, pos_offset = {x = -350, y = 210}, life_time = 1.8},
		{template = laser_light_projection, angle_offset = -36, pos_offset = {x = -350, y = 280}, life_time = 1.9},
		{template = laser_light_projection, angle_offset = -45, pos_offset = {x = -350, y = 350}, life_time = 2},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_laser_arc_right = {
	projectiles = {
		{template = laser_light_projection, angle_offset = -135, pos_offset = {x = 350, y = 350}, life_time = 1},
		{template = laser_light_projection, angle_offset = -144, pos_offset = {x = 350, y = 280}, life_time = 1.1},
		{template = laser_light_projection, angle_offset = -153, pos_offset = {x = 350, y = 210}, life_time = 1.2},
		{template = laser_light_projection, angle_offset = -162, pos_offset = {x = 350, y = 140}, life_time = 1.3},
		{template = laser_light_projection, angle_offset = -171, pos_offset = {x = 350, y = 70}, life_time = 1.4},
		{template = laser_light_projection, angle_offset = -180, pos_offset = {x = 350, y = 0}, life_time = 1.5},
		{template = laser_light_projection, angle_offset = 171, pos_offset = {x = 350, y = -70}, life_time = 1.6},
		{template = laser_light_projection, angle_offset = 162, pos_offset = {x = 350, y = -140}, life_time = 1.7},
		{template = laser_light_projection, angle_offset = 153, pos_offset = {x = 350, y = -210}, life_time = 1.8},
		{template = laser_light_projection, angle_offset = 144, pos_offset = {x = 350, y = -280}, life_time = 1.9},
		{template = laser_light_projection, angle_offset = 135, pos_offset = {x = 350, y = -350}, life_time = 2},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_beam_square_up_right = {
	projectiles = {
		{template = beam_small, angle_offset = 180, pos_offset = {x = 500, y = 0}, life_time = 9},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -1000, y = -500}, life_time = 9},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -1500, y = 1000}, life_time = 9},
		{template = beam_small, angle_offset = -90, pos_offset = {x = 0, y = 1500}, life_time = 9},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.world,
}
local attack_laser_heavy = {
	projectiles = {
		{template = laser_heavy, angle_offset = 0, pos_offset = {x = 0, y = 0}, travel_distance = 2000},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_laser_run_setup = {
	projectiles = {
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = -360}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = -410}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = -460}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = -510}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = -560}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = 360}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = 410}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = 460}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = 510}, life_time = 20},
		{template = beam_small, angle_offset = 0, pos_offset = {x = -400, y = 560}, life_time = 20},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -400, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -450, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -500, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -550, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = -600, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = 1600, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = 1650, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = 1700, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = 1750, y = -1000}, life_time = 8},
		{template = beam_small, angle_offset = 90, pos_offset = {x = 1800, y = -1000}, life_time = 8},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}
local attack_beam_run = {
	projectiles = {
		{template = beam_small, angle_offset = 0, pos_offset = {x = 0, y = 0}, life_time = 10, track = true},
	},
	source_pos = source_types.enemy,
	aim_pos = aim_types.enemy,
}
local attack_laser_heavy_wall_run = {
	projectiles = {
		{template = laser_heavy, angle_offset = 180, pos_offset = {x = 500, y = -25}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = 180, pos_offset = {x = 500, y = 0}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = 180, pos_offset = {x = 500, y = 25}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = 90, pos_offset = {x = 0, y = -360}, travel_distance = 2000},
		{template = laser_heavy, angle_offset = -90, pos_offset = {x = 0, y = 360}, travel_distance = 2000},
	},
	source_pos = source_types.player,
	aim_pos = aim_types.world,
}

--ATTACK SEQUENCES--
--Phase 1--
local shotgun_sequence_down = {}
local shotgun_sequence_up = {}
local shotgun_sequence_around = {}
local beam_sequence_swipe_down = {}

do
	shotgun_sequence_down.name = "shotgun_sequence_down"
	shotgun_sequence_down.duration = 4
	shotgun_sequence_down.move_sequence = {
		{time = 1, x = 0, y = -300, angle = 90, relative = true, track = true},
		{time = 2, x = 0, y = 0, angle = 90, set_angle = true}, --hold
		{time = 3, x = 0, y = -300, angle = 90, relative = true, track = true}, --move
		{time = 4, x = 0, y = 0, angle = 90, set_angle = true}, --hold
	}
	shotgun_sequence_down.attack_sequence = {
		{time = 1.25, attack = attack_shotgun},
		{time = 3.25, attack = attack_shotgun},
		{time = 5.25, attack = attack_shotgun},
	}
	shotgun_sequence_down.transfer_sequences = {
		shotgun_sequence_around,
		beam_sequence_swipe_down,
	}

	shotgun_sequence_up.name = "shotgun_sequence_up"
	shotgun_sequence_up.duration = 4
	shotgun_sequence_up.move_sequence = {
		{time = 1, x = 0, y = 300, angle = -90, relative = true, track = true},
		{time = 2, x = 0, y = 0, angle = -90, set_angle = true}, --hold
		{time = 3, x = 0, y = 300, angle = -90, relative = true, track = true}, --move
		{time = 4, x = 0, y = 0, angle = -90, set_angle = true}, --hold
	}
	shotgun_sequence_up.attack_sequence = {
		{time = 1.25, attack = attack_shotgun},
		{time = 3.25, attack = attack_shotgun},
		{time = 5.25, attack = attack_shotgun},
	}
	shotgun_sequence_up.transfer_sequences = {
		shotgun_sequence_around,
		beam_sequence_swipe_down,
	}
	shotgun_sequence_around.name = "shotgun_sequence_around"
	shotgun_sequence_around.duration = 8
	shotgun_sequence_around.move_sequence = {
		{time = 1, x = 0, y = -300, angle = 90, relative = true, track = true},
		{time = 2, x = 0, y = 0, angle = 90, set_angle = true}, --hold
		{time = 3, x = 300, y = 0, angle = 180, relative = true, track = true}, --move
		{time = 4, x = 0, y = 0, angle = 180, set_angle = true}, --hold
		{time = 5, x = 0, y = 300, angle = -90, relative = true, track = true}, --move
		{time = 6, x = 0, y = 0, angle = -90, set_angle = true}, --hold
		{time = 7, x = -300, y = 9, angle = 0, relative = true, track = true}, --move
		{time = 8, x = 0, y = 0, angle = 0, set_angle = true}, --hold
	}
	shotgun_sequence_around.attack_sequence = {
		{time = 1.25, attack = attack_shotgun},
		{time = 3.25, attack = attack_shotgun},
		{time = 5.25, attack = attack_shotgun},
		{time = 7.25, attack = attack_shotgun},
	}
	shotgun_sequence_around.transfer_sequences = {
		shotgun_sequence_down,
		shotgun_sequence_up,
	}
	beam_sequence_swipe_down.name = "beam_sequence_swipe_down"
	beam_sequence_swipe_down.duration = 6
	beam_sequence_swipe_down.move_sequence = {
		{time = 1, x = 400, y = -300, angle = 180, relative = true, track = true},
		{time = 6, x = 0, y = 600, angle = 180, set_angle = true}, --move
	}
	beam_sequence_swipe_down.attack_sequence = {
		{time = 1, attack = attack_beam},
	}
	beam_sequence_swipe_down.transfer_sequences = {
		shotgun_sequence_down,
		shotgun_sequence_up,
		shotgun_sequence_around,
	}
end

--Phase 2--
local beam_sequence_swipe_spin = {}
local beam_sequence_swipe_swap = {}
local beam_sequence_grid_horizontal = {}
local beam_sequence_grid_vertical = {}

do
	beam_sequence_swipe_spin.name = "beam_sequence_swipe_spin"
	beam_sequence_swipe_spin.duration = 6.5
	beam_sequence_swipe_spin.move_sequence = {
		{time = 1, x = 150, y = 150, angle = 90, relative = true, track = true},
		{time = 2, x = 0, y = -50, angle = 90, linear = true, set_angle = true}, --hold
		{time = 3, x = 50, y = 0, angle = 180, linear = true, linear_angle = true}, --first quarter
		{time = 4, x = 0, y = 50, angle = -90, linear = true, linear_angle = true}, --second quarter
		{time = 5, x = -50, y = 0, angle = 0, linear = true, linear_angle = true}, --third quarter
		{time = 6, x = 0, y = -50, angle = 90, linear = true, linear_angle = true}, --forth quarter
		{time = 6.5, x = 0, y = 50, angle = 90, linear = true, set_angle = true}, --hold
	}
	beam_sequence_swipe_spin.attack_sequence = {
		{time = 1, attack = attack_beam},
	}
	beam_sequence_swipe_spin.transfer_sequences = {
		beam_sequence_swipe_swap,
		beam_sequence_grid_vertical,
	}
	beam_sequence_swipe_swap.name = "beam_sequence_swipe_swap"
	beam_sequence_swipe_swap.duration = 8
	beam_sequence_swipe_swap.move_sequence = {
		{time = 1, x = 400, y = -170, angle = 180, relative = true, track = true},
		{time = 2, x = 0, y = 200, angle = 180, linear = true, set_angle = true}, --hold
		{time = 3, x = 400, y = 170, angle = 180, relative = true, track = true},
		{time = 4, x = 0, y = -200, angle = 180, linear = true, set_angle = true}, --hold
		{time = 5, x = 400, y = -170, angle = 180, relative = true, track = true},
		{time = 6, x = 0, y = 200, angle = 180, linear = true, set_angle = true}, --hold
		{time = 7, x = 400, y = 170, angle = 180, relative = true, track = true},
		{time = 8, x = 0, y = -200, angle = 180, linear = true, set_angle = true}, --hold
	}
	beam_sequence_swipe_swap.attack_sequence = {
		{time = 1, attack = attack_beam_pinpoint},
		{time = 3, attack = attack_beam_pinpoint},
		{time = 5, attack = attack_beam_pinpoint},
		{time = 7, attack = attack_beam_pinpoint},
	}
	beam_sequence_swipe_swap.transfer_sequences = {
		beam_sequence_swipe_spin,
		beam_sequence_grid_horizontal,
	}
	beam_sequence_grid_horizontal.name = "beam_sequence_grid_horizontal"
	beam_sequence_grid_horizontal.duration = 4
	beam_sequence_grid_horizontal.move_sequence = {
		{time = 1, x = 500, y = 0, angle = 180, relative = true, track = true},
		{time = 3, x = 0, y = 0, angle = 180, linear = true, set_angle = true}, --hold
	}
	beam_sequence_grid_horizontal.attack_sequence = {
		{time = 1, attack = attack_beam_grid_hori},
	}
	beam_sequence_grid_horizontal.transfer_sequences = {
		beam_sequence_swipe_swap,
		beam_sequence_grid_vertical,
	}
	beam_sequence_grid_vertical.name = "beam_sequence_grid_vertical"
	beam_sequence_grid_vertical.duration = 4
	beam_sequence_grid_vertical.move_sequence = {
		{time = 1, x = 0, y = -300, angle = 90, relative = true, track = true},
		{time = 3, x = 0, y = 0, angle = 90, linear = true, set_angle = true}, --hold
	}
	beam_sequence_grid_vertical.attack_sequence = {
		{time = 1, attack = attack_beam_grid_vert},
	}
	beam_sequence_grid_vertical.transfer_sequences = {
		beam_sequence_swipe_spin,
		beam_sequence_grid_horizontal,
	}
end

--Phase 3--
local heavy_sequence_quad_spin = {}
local mine_sequence_dash_up = {}
local mine_sequence_dash_right = {}
local laser_sequence_arc_up = {}
local laser_sequence_arc_down = {}
local laser_sequence_arc_left = {}
local laser_sequence_arc_right = {}

do
	heavy_sequence_quad_spin.name = "heavy_sequence_quad_spin"
	heavy_sequence_quad_spin.duration = 10
	heavy_sequence_quad_spin.move_sequence = {
		{time = 1, x = 350, y = 0, angle = -180, relative = true, track = true},
		{time = 2, x = 0, y = 0, angle = -135, linear = true, linear_angle = true}, --first quarter
		{time = 3, x = 0, y = 0, angle = -90, linear = true, linear_angle = true}, --second quarter
		{time = 4, x = 0, y = 0, angle = -45, linear = true, linear_angle = true}, --third quarter
		{time = 5, x = 0, y = 0, angle = 0, linear = true, linear_angle = true}, --forth quarter
		{time = 6, x = 0, y = 0, angle = 45, linear = true, linear_angle = true}, --first quarter
		{time = 7, x = 0, y = 0, angle = 90, linear = true, linear_angle = true}, --second quarter
		{time = 8, x = 0, y = 0, angle = 135, linear = true, linear_angle = true}, --third quarter
		{time = 9, x = 0, y = 0, angle = 180, linear = true, linear_angle = true}, --forth quarter
		{time = 10, x = 0, y = 0, angle = 180, linear = true, linear_angle = true}, --hold
	}
	heavy_sequence_quad_spin.attack_sequence = {
		{time = 1, attack = attack_star_quad},
		{time = 1.25, attack = attack_star_quad},
		{time = 1.5, attack = attack_star_quad},
		{time = 1.75, attack = attack_star_quad},
		{time = 2, attack = attack_star_quad},
		{time = 2.25, attack = attack_star_quad},
		{time = 2.5, attack = attack_star_quad},
		{time = 2.75, attack = attack_star_quad},
		{time = 3, attack = attack_star_quad},
		{time = 3.25, attack = attack_star_quad},
		{time = 3.5, attack = attack_star_quad},
		{time = 3.75, attack = attack_star_quad},
		{time = 4, attack = attack_star_quad},
		{time = 4.25, attack = attack_star_quad},
		{time = 4.5, attack = attack_star_quad},
		{time = 4.75, attack = attack_star_quad},
		{time = 5, attack = attack_star_quad},
		{time = 5.25, attack = attack_star_quad},
		{time = 5.5, attack = attack_star_quad},
		{time = 5.75, attack = attack_star_quad},
		{time = 6, attack = attack_star_quad},
		{time = 6.25, attack = attack_star_quad},
		{time = 6.5, attack = attack_star_quad},
		{time = 6.75, attack = attack_star_quad},
		{time = 7, attack = attack_star_quad},
		{time = 7.25, attack = attack_star_quad},
		{time = 7.5, attack = attack_star_quad},
		{time = 7.75, attack = attack_star_quad},
		{time = 8, attack = attack_star_quad},
		{time = 8.25, attack = attack_star_quad},
		{time = 8.5, attack = attack_star_quad},
		{time = 8.75, attack = attack_star_quad},
		{time = 9, attack = attack_star_quad},
	}
	heavy_sequence_quad_spin.transfer_sequences = {
		mine_sequence_dash_up,
		mine_sequence_dash_right,
	}

	mine_sequence_dash_up.name = "mine_sequence_dash_up"
	mine_sequence_dash_up.duration = 2
	mine_sequence_dash_up.move_sequence = {
		{time = 1, x = 0, y = 360, angle = -90, relative = true, track = true},
		{time = 1.25, x = 0, y = 0, angle = -90, linear = true, set_angle = true},
		{time = 2, x = 0, y = -720, angle = -90, linear = true, set_angle = true},
	}
	mine_sequence_dash_up.attack_sequence = {
		{time = 1.25, attack = attack_mine_drop},
		{time = 1.375, attack = attack_mine_drop},
		{time = 1.5, attack = attack_mine_drop},
		{time = 1.625, attack = attack_mine_drop},
		{time = 1.75, attack = attack_mine_drop},
		{time = 1.875, attack = attack_mine_drop},
		{time = 2, attack = attack_mine_drop},
	}
	mine_sequence_dash_up.transfer_sequences = {
		laser_sequence_arc_left,
		laser_sequence_arc_right,
	}

	mine_sequence_dash_right.name = "mine_sequence_dash_right"
	mine_sequence_dash_right.duration = 2
	mine_sequence_dash_right.move_sequence = {
		{time = 1, x = -360, y = 0, angle = 0, relative = true, track = true},
		{time = 1.25, x = 0, y = 0, angle = 0, linear = true, set_angle = true},
		{time = 2, x = 720, y = 0, angle = 0, linear = true, set_angle = true},
	}
	mine_sequence_dash_right.attack_sequence = {
		{time = 1.25, attack = attack_mine_drop},
		{time = 1.375, attack = attack_mine_drop},
		{time = 1.5, attack = attack_mine_drop},
		{time = 1.625, attack = attack_mine_drop},
		{time = 1.75, attack = attack_mine_drop},
		{time = 1.875, attack = attack_mine_drop},
		{time = 2, attack = attack_mine_drop},
	}
	mine_sequence_dash_right.transfer_sequences = {
		laser_sequence_arc_left,
		laser_sequence_arc_right,
	}

	laser_sequence_arc_up.name = "laser_sequence_arc_up"
	laser_sequence_arc_up.duration = 3
	laser_sequence_arc_up.move_sequence = {
		{time = 1, x = 350, y = -350, angle = 135, relative = true},
		{time = 2, x = -700, y = 0, angle = 45, linear = true, linear_angle = true},
		{time = 3, x = 0, y = -350, angle = 90, relative = true, linear_angle = true, track = true},
	}
	laser_sequence_arc_up.attack_sequence = {
		{time = 0, attack = attack_laser_arc_up},
	}
	laser_sequence_arc_up.transfer_sequences = {
		mine_sequence_dash_up,
		mine_sequence_dash_right,
	}

	laser_sequence_arc_down.name = "laser_sequence_arc_down"
	laser_sequence_arc_down.duration = 3
	laser_sequence_arc_down.move_sequence = {
		{time = 1, x = -350, y = 350, angle = -45, relative = true},
		{time = 2, x = 700, y = 0, angle = -135, linear = true, linear_angle = true},
		{time = 3, x = 0, y = 350, angle = -90, relative = true, linear_angle = true, track = true},
	}
	laser_sequence_arc_down.attack_sequence = {
		{time = 0, attack = attack_laser_arc_down},
	}
	laser_sequence_arc_down.transfer_sequences = {
		mine_sequence_dash_up,
		mine_sequence_dash_right,
	}

	laser_sequence_arc_left.name = "laser_sequence_arc_left"
	laser_sequence_arc_left.duration = 3
	laser_sequence_arc_left.move_sequence = {
		{time = 1, x = -350, y = -350, angle = 45, relative = true},
		{time = 2, x = 0, y = 700, angle = -45, linear = true, linear_angle = true},
		{time = 3, x = -350, y = 0, angle = 0, relative = true, linear_angle = true, track = true},
	}
	laser_sequence_arc_left.attack_sequence = {
		{time = 0, attack = attack_laser_arc_left},
	}
	laser_sequence_arc_left.transfer_sequences = {
		laser_sequence_arc_up,
		laser_sequence_arc_down,
	}

	laser_sequence_arc_right.name = "laser_sequence_arc_right"
	laser_sequence_arc_right.duration = 3
	laser_sequence_arc_right.move_sequence = {
		{time = 1, x = 350, y = 350, angle = -135, relative = true},
		{time = 2, x = 0, y = -700, angle = 135, linear = true, linear_angle = true},
		{time = 3, x = 350, y = 0, angle = 180, relative = true, linear_angle = true, track = true},
	}
	laser_sequence_arc_right.attack_sequence = {
		{time = 0, attack = attack_laser_arc_right},
	}
	laser_sequence_arc_right.transfer_sequences = {
		laser_sequence_arc_up,
		laser_sequence_arc_down,
	}
end

--Phase 4--
local laser_sequence_run_setup = {}

do
	laser_sequence_run_setup.name = "laser_sequence_run_setup"
	laser_sequence_run_setup.duration = 18
	laser_sequence_run_setup.move_sequence = {
		{time = 1.25, x = 0, y = -360, angle = 90, relative = true, track = true},
		{time = 2, x = 0, y = 720, angle = 90, linear = true, linear_angle = true},
		{time = 2.25, x = 0, y = 360, angle = -90, relative = true, track = true},
		{time = 3, x = 0, y = -720, angle = -90, linear = true, linear_angle = true},
		{time = 3.25, x = 0, y = -360, angle = 90, relative = true, track = true},
		{time = 4, x = 0, y = 720, angle = 90, linear = true, linear_angle = true},
		{time = 4.25, x = 0, y = 360, angle = -90, relative = true, track = true},
		{time = 5, x = 0, y = -720, angle = -90, linear = true, linear_angle = true},
		{time = 5.25, x = 0, y = -360, angle = 90, relative = true, track = true},
		{time = 6, x = 0, y = 720, angle = 90, linear = true, linear_angle = true},
		{time = 6.25, x = 0, y = 360, angle = -90, relative = true, track = true},
		{time = 7, x = 0, y = -720, angle = -90, linear = true, linear_angle = true},
		{time = 8, x = 360, y = -360, angle = 90, relative = true, track = true},
		{time = 11, x = 180, y = -360, angle = 90, relative = true, track = true, linear_angle = true, linear = true},
		{time = 14, x = 90, y = -360, angle = 90, relative = true, track = true, linear_angle = true, linear = true},
		{time = 16, x = 45, y = -360, angle = 90, relative = true, track = true, linear_angle = true, linear = true},
		{time = 18, x = 22.5, y = -360, angle = 90, relative = true, track = true, linear_angle = true, linear = true},
	}
	laser_sequence_run_setup.attack_sequence = {
		{time = 0, attack = attack_laser_run_setup},
		{time = 1.25, attack = attack_mine_drop},
		{time = 1.375, attack = attack_mine_drop},
		{time = 1.5, attack = attack_mine_drop},
		{time = 1.625, attack = attack_mine_drop},
		{time = 1.75, attack = attack_mine_drop},
		{time = 1.875, attack = attack_mine_drop},
		{time = 2, attack = attack_mine_drop},
		{time = 2.25, attack = attack_mine_drop},
		{time = 2.375, attack = attack_mine_drop},
		{time = 2.5, attack = attack_mine_drop},
		{time = 2.625, attack = attack_mine_drop},
		{time = 2.75, attack = attack_mine_drop},
		{time = 2.875, attack = attack_mine_drop},
		{time = 3, attack = attack_mine_drop},
		{time = 3.25, attack = attack_mine_drop},
		{time = 3.375, attack = attack_mine_drop},
		{time = 3.5, attack = attack_mine_drop},
		{time = 3.625, attack = attack_mine_drop},
		{time = 3.75, attack = attack_mine_drop},
		{time = 3.875, attack = attack_mine_drop},
		{time = 4, attack = attack_mine_drop},
		{time = 4.25, attack = attack_mine_drop},
		{time = 4.375, attack = attack_mine_drop},
		{time = 4.5, attack = attack_mine_drop},
		{time = 4.625, attack = attack_mine_drop},
		{time = 4.75, attack = attack_mine_drop},
		{time = 4.875, attack = attack_mine_drop},
		{time = 5, attack = attack_mine_drop},
		{time = 5.25, attack = attack_mine_drop},
		{time = 5.375, attack = attack_mine_drop},
		{time = 5.5, attack = attack_mine_drop},
		{time = 5.625, attack = attack_mine_drop},
		{time = 5.75, attack = attack_mine_drop},
		{time = 5.875, attack = attack_mine_drop},
		{time = 6, attack = attack_mine_drop},
		{time = 6.25, attack = attack_mine_drop},
		{time = 6.375, attack = attack_mine_drop},
		{time = 6.5, attack = attack_mine_drop},
		{time = 6.625, attack = attack_mine_drop},
		{time = 6.75, attack = attack_mine_drop},
		{time = 6.875, attack = attack_mine_drop},
		{time = 7, attack = attack_mine_drop},
		{time = 8, attack = attack_beam_run},
		{time = 10, attack = attack_laser_heavy_wall_run},
		{time = 12, attack = attack_laser_heavy_wall_run},
		{time = 14, attack = attack_laser_heavy_wall_run},
		{time = 15.5, attack = attack_laser_heavy_wall_run},
		{time = 17, attack = attack_laser_heavy_wall_run},
	}
	laser_sequence_run_setup.transfer_sequences = {
		laser_sequence_arc_up,
		laser_sequence_arc_down,
	}
end

--Phase 5--
local laser_sequence_arc_surround = {}

do
	laser_sequence_arc_surround.name = "laser_sequence_arc_surround"
	laser_sequence_arc_surround.duration = 10.5
	laser_sequence_arc_surround.move_sequence = {
		{time = 0.95, x = 500, y = -500, angle = 135, relative = true},
		{time = 1, x = 0, y = 0, angle = 135, linear = true},
		{time = 2.5, x = -1000, y = 0, angle = 45, linear = true, linear_angle = true},
		{time = 4, x = 0, y = 1000, angle = -45, linear = true, linear_angle = true},
		{time = 5.5, x = 1000, y = 0, angle = -135, linear = true, linear_angle = true},
		{time = 7, x = 0, y = -1000, angle = 135, linear = true, linear_angle = true},
		{time = 8.5, x = -1000, y = 0, angle = 45, linear = true, linear_angle = true},
		{time = 10, x = 0, y = 1000, angle = -45, linear = true, linear_angle = true},
		{time = 10.5, x = 0, y = 0, angle = -45, linear = true, linear_angle = true},
	}
	laser_sequence_arc_surround.attack_sequence = {
		{time = 1, attack = attack_beam_square_up_right},
		{time = 1, attack = attack_laser_heavy},
		{time = 1.45, attack = attack_laser_heavy},
		{time = 1.8, attack = attack_laser_heavy},
		{time = 2.05, attack = attack_laser_heavy},
		{time = 2.2, attack = attack_laser_heavy},
		{time = 2.35, attack = attack_laser_heavy},
		{time = 2.5, attack = attack_laser_heavy},
		{time = 2.65, attack = attack_laser_heavy},
		{time = 2.8, attack = attack_laser_heavy},
		{time = 2.95, attack = attack_laser_heavy},
		{time = 3.10, attack = attack_laser_heavy},
		{time = 3.25, attack = attack_laser_heavy},
		{time = 3.4, attack = attack_laser_heavy},
		{time = 3.55, attack = attack_laser_heavy},
		{time = 3.7, attack = attack_laser_heavy},
		{time = 3.85, attack = attack_laser_heavy},
		{time = 4, attack = attack_laser_heavy},
		{time = 4.15, attack = attack_laser_heavy},
		{time = 4.3, attack = attack_laser_heavy},
		{time = 4.45, attack = attack_laser_heavy},
		{time = 4.6, attack = attack_laser_heavy},
		{time = 4.75, attack = attack_laser_heavy},
		{time = 4.9, attack = attack_laser_heavy},
		{time = 5.05, attack = attack_laser_heavy},
		{time = 5.2, attack = attack_laser_heavy},
		{time = 5.35, attack = attack_laser_heavy},
		{time = 5.5, attack = attack_laser_heavy},
		{time = 5.65, attack = attack_laser_heavy},
		{time = 5.8, attack = attack_laser_heavy},
		{time = 5.95, attack = attack_laser_heavy},
		{time = 6.10, attack = attack_laser_heavy},
		{time = 6.25, attack = attack_laser_heavy},
		{time = 6.4, attack = attack_laser_heavy},
		{time = 6.55, attack = attack_laser_heavy},
		{time = 6.7, attack = attack_laser_heavy},
		{time = 6.85, attack = attack_laser_heavy},
		{time = 7, attack = attack_laser_heavy},
		{time = 7.15, attack = attack_laser_heavy},
		{time = 7.3, attack = attack_laser_heavy},
		{time = 7.45, attack = attack_laser_heavy},
		{time = 7.6, attack = attack_laser_heavy},
		{time = 7.5, attack = attack_laser_heavy},
		{time = 7.9, attack = attack_laser_heavy},
		{time = 8.05, attack = attack_laser_heavy},
		{time = 8.2, attack = attack_laser_heavy},
		{time = 8.35, attack = attack_laser_heavy},
		{time = 8.5, attack = attack_laser_heavy},
		{time = 8.65, attack = attack_laser_heavy},
		{time = 8.8, attack = attack_laser_heavy},
		{time = 8.95, attack = attack_laser_heavy},
		{time = 9.10, attack = attack_laser_heavy},
		{time = 9.25, attack = attack_laser_heavy},
		{time = 9.4, attack = attack_laser_heavy},
		{time = 9.55, attack = attack_laser_heavy},
		{time = 9.7, attack = attack_laser_heavy},
		{time = 9.85, attack = attack_laser_heavy},
		{time = 10, attack = attack_laser_heavy},
	}
	laser_sequence_arc_surround.transfer_sequences = {
		laser_sequence_arc_left,
		laser_sequence_arc_right,
	}
end

local enemy_sequences = {
	shotgun_sequence_down,
	shotgun_sequence_up,
	shotgun_sequence_around,
	beam_sequence_swipe_down,
}

local object_types = {player = 1, enemy = 2, player_projectile = 3, enemy_projectile = 4, player_drone = 5}
local weapon_types = {LASER = 1, BURST = 2, MISSILES = 3, BEAM = 4, BOMB = 5}

--local object_list = {}
local player_drones = {}
local enemy_ships = {}
local player_projectiles = {}
local enemy_projectiles = {}
local explosion_list = {}

local controls = {
	up_key_var = "aea_supernova_up",
	down_key_var = "aea_supernova_down",
	left_key_var = "aea_supernova_left",
	right_key_var = "aea_supernova_right",
	held_up = false,
	held_down = false,
	held_left = false,
	held_right = false,
	held_vert = 0,
	held_hori = 0,
	held_fire = false,
}

local player_ship_stats = {
	max_health = 250,
	max_speed = 250,
	acceleration = 250,
	drag = 75,
	rotation_speed = 180,
	i_frames = 2,
}

local player_ship = {
	type = object_types.player,
	pos = {x = 0, y = 0},
	velocity = {x = 0, y = 0},
	angle = 0,
	collider_radius = 30,
	health = 100,
	i_frames = 0,
	image = nil,
	weapons = {},
}
local player_ship_weapon_offsets = {}
player_ship_weapon_offsets[1] = {x = 0, y = -14}
player_ship_weapon_offsets[2] = {x = 0, y = 14}
player_ship_weapon_offsets[3] = {x = 0, y = -28}
player_ship_weapon_offsets[4] = {x = 0, y = 28}
player_ship_weapon_offsets[5] = {x = 0, y = -21}
player_ship_weapon_offsets[6] = {x = 0, y = 21}
player_ship_weapon_offsets[7] = {x = 0, y = -7}
player_ship_weapon_offsets[8] = {x = 0, y = 7}


local background_layers = {
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/asteroid_back1_1.png", 0, 0, 0, colour_base, 1, false),
		width = 546,
		height = 309,
		parallax_scale = 0.25,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/asteroid_back1_2.png", 0, 0, 0, colour_base, 1, false),
		width = 546,
		height = 309,
		parallax_scale = 0.3,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back1_3.png", 0, 0, 0, colour_base, 1, false),
		width = 546,
		height = 309,
		parallax_scale = 0.35,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back1_4.png", 0, 0, 0, colour_base, 1, false),
		width = 546,
		height = 309,
		parallax_scale = 0.4,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back2_1.png", 0, 0, 0, colour_base, 1, false),
		width = 388*2,
		height = 446*2,
		parallax_scale = 0.55,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back2_2.png", 0, 0, 0, colour_base, 1, false),
		width = 388,
		height = 446,
		parallax_scale = 0.6,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back2_3.png", 0, 0, 0, colour_base, 1, false),
		width = 388,
		height = 446,
		parallax_scale = 0.65,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back2_4.png", 0, 0, 0, colour_base, 1, false),
		width = 388*2,
		height = 446*2,
		parallax_scale = 0.7,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back3_1.png", 0, 0, 0, colour_base, 1, false),
		width = 476,
		height = 439,
		parallax_scale = 0.85,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back3_2.png", 0, 0, 0, colour_base, 1, false),
		width = 476,
		height = 439,
		parallax_scale = 0.9,
	},
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back3_3.png", 0, 0, 0, colour_base, 1, false),
		width = 476,
		height = 439,
		parallax_scale = 0.95,
	},
}

local foreground_layers = {
	{
		image = Hyperspace.Resources:CreateImagePrimitiveString("asteroids/aea_asteroid_back3_4.png", 0, 0, 0, colour_base, 1, false),
		width = 476,
		height = 439,
		parallax_scale = 1,
	},
}

local back_images = {
	Hyperspace.Resources:CreateImagePrimitiveString("stars/bg_dullstars.png", 0, 0, 0, colour_base, 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("stars/bg_dullstars2.png", 0, 0, 0, colour_base, 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("stars/bg_dullstars3.png", 0, 0, 0, colour_base, 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("stars/bg_dullstars4.png", 0, 0, 0, colour_base, 1, false),
	Hyperspace.Resources:CreateImagePrimitiveString("stars/bg_dullstars5.png", 0, 0, 0, colour_base, 1, false),
}

--Game functions

local back_image_index = 1
local relative_mode = false
local active_var = "aea_supernova_active"

local function setup_weapon(weapon, i)
	local new_weapon = nil
	local weapon_type = weapon_types[weapon.blueprint.typeName]
	if weapon_type == weapon_types.LASER then
		new_weapon = {
			current_cooldown = 0,
			cooldown = 0.33,
			shots = 1,
			accuracy = 0,
			pos_offset = player_ship_weapon_offsets[i],
			template = player_laser_light,
		}
	elseif weapon_type == weapon_types.BURST then
		new_weapon = {
			current_cooldown = 0,
			cooldown = 1,
			shots = 4,
			accuracy = 3,
			pos_offset = player_ship_weapon_offsets[i],
			template = player_flak_small,
		}
	elseif weapon_type == weapon_types.MISSILES then
		new_weapon = {
			current_cooldown = 0,
			cooldown = 1,
			shots = 1,
			accuracy = 0,
			pos_offset = player_ship_weapon_offsets[i],
			template = player_missile_small,
		}
	elseif weapon_type == weapon_types.BEAM then
		new_weapon = {
			beam = true,
			current_cooldown = 0,
			cooldown = 0.5,
			shots = 1,
			accuracy = 0,
			pos_offset = player_ship_weapon_offsets[i],
			template = player_beam_small,
		}
	elseif weapon_type == weapon_types.BOMB then
		new_weapon = {
			teleport = true,
			current_cooldown = 0,
			cooldown = 1,
			shots = 1,
			accuracy = 0,
			pos_offset = player_ship_weapon_offsets[i],
			template = player_bomb_small,
		}
	end
	return new_weapon
end

local function setup_drone()
	local new_drone = {
		type = object_types.player_drone,
		pos = {x = math.random(-20, 20), y = math.random(-20, 20)},
		velocity = {x = 0, y = 0},
		angle = 0,
		image = Hyperspace.Resources:CreateImagePrimitiveString("ship/drones/drone_aea_supernova.png", -16, -16, 0, colour_base, 1, false),
		cooldown = 0.5,
		collider_radius = 10,
		current_cooldown = 0,
		template = player_laser_light,
	}
	return new_drone
end

function start_mode()
	back_image_index = math.random(#back_images)
	local shipManager = Hyperspace.ships.player
	Hyperspace.playerVariables[active_var] = 1
	player_ship.pos = {x = 0, y = 0}
	player_ship.velocity = {x = 0, y = 0}
	player_ship.angle = 0
	local shipImg = shipManager.myBlueprint.imgFile
	player_ship.image = Hyperspace.Resources:CreateImagePrimitiveString("customizeUI/miniship_"..shipImg.."_base.png", -95, -60, 0, colour_base, 1, false)
	player_ship.health = player_ship_stats.max_health
	player_ship.max_health = player_ship_stats.max_health
	player_ship.i_frames = 0

	player_ship.weapons = {}
	local i = 1
	if shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			table.insert(player_ship.weapons, setup_weapon(weapon, i))
			i = (i % #player_ship_weapon_offsets) + 1
		end
	end
	if shipManager:HasSystem(11) then
		for artillery in vter(shipManager.artillerySystems) do
			table.insert(player_ship.weapons, setup_weapon(artillery.projectileFactory, i))
			i = (i % #player_ship_weapon_offsets) + 1
		end
	end

	player_drones = {}
	if shipManager:HasSystem(4) then
		for drone in vter(shipManager.droneSystem.drones) do
			if drone.type == 1 then
				table.insert(player_drones, setup_drone())
			end
		end
	end

	Hyperspace.playerVariables[controls.up_key_var] = 119 --Hyperspace.SDLKey.SDLK_w
	Hyperspace.playerVariables[controls.down_key_var] = 115 --Hyperspace.SDLKey.SDLK_s
	Hyperspace.playerVariables[controls.left_key_var] = 97 --Hyperspace.SDLKey.SDLK_a
	Hyperspace.playerVariables[controls.right_key_var] = 100 --Hyperspace.SDLKey.SDLK_d
	enemy_ships = {}
	player_projectiles = {}
	enemy_projectiles = {}
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, "AEA_EVENT_EMPTY_LOAD", false,-1)
end

local function end_mode()
	Hyperspace.playerVariables[active_var] = 0
	local worldManager = Hyperspace.App.world
	Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, "AEA_EVENT_EMPTY_EXIT", false,-1)
end

local function spawn_enemy()
	local enemy_ship = {
		type = object_types.enemy,
		pos = {x = 0, y = 0},
		velocity = {x = 0, y = 0},
		angle = 0,
		angular_velocity = 0,
		collider_radius = 60,
		health = 10000,
		max_health = 10000,
		health_thresholds = {
			{health = 100, sequence = laser_sequence_arc_surround, i_frames = 30},
			{health = 2000, sequence = laser_sequence_arc_surround, i_frames = 5},
			{health = 4000, sequence = laser_sequence_run_setup, i_frames = 5},
			{health = 6000, sequence = heavy_sequence_quad_spin, i_frames = 5},
			{health = 8000, sequence = beam_sequence_swipe_spin, i_frames = 5},
		},
		current_sequence = beam_sequence_swipe_down,
		current_attack = 1,
		sequence_time = 0,
		active_beams = {},
		image = Hyperspace.Resources:CreateImagePrimitiveString("customizeUI/aeap_supernova_boss.png", -91, -103, 0, colour_base, 1, false),
	}
	table.insert(enemy_ships, enemy_ship)
end

--Update Game
local death_explosion = "explosion_big2"
local death_explosion_sound = "smallExplosion"
local damage_explosion = "explosion_big2"
local damage_explosion_sound = "smallExplosion"

local function create_explosion(pos, image, sound)
	local anim = Hyperspace.Animations:GetAnimation(image)
	anim.position.x = pos.x - anim.info.frameWidth/2
	anim.position.y = pos.y - anim.info.frameHeight/2
	anim.tracker.loop = false
	anim:Start(true)
	table.insert(explosion_list, anim)
	Hyperspace.Sounds:PlaySoundMix(sound, -1, false)
end

local function damage_object(object, damage)
	if damage == 0 then return nil end
	object.health = object.health - damage
	if object.type == object_types.player then
		create_explosion(object.pos, damage_explosion, damage_explosion_sound)
		object.i_frames = player_ship_stats.i_frames
	end
	if object.health <= 0 and object.type == object_types.player then
		--print("player dead")
		create_explosion(object.pos, death_explosion, death_explosion_sound)
	elseif object.health <= 0 and object.type == object_types.enemy then
		create_explosion(object.pos, death_explosion, death_explosion_sound)
	elseif object.health <= 0 then
		return true
	end
	return nil
end

local function create_explosion_collision(ship, pos, radius, damage)
	if (not (ship.i_frames and ship.i_frames > 0)) and get_distance(ship.pos, pos) <= ship.collider_radius + radius then
		damage_object(ship, damage)
	end
end

local function update_player_velocity(ship)
	local input_velocity = {
		x = controls.held_hori,
		y = controls.held_vert,
	}

	local input_mag = get_mag(input_velocity)
	if input_mag > 1 then
		local normalized_input = normalize(input_velocity)
		input_velocity = normalized_input
	end

	ship.velocity.x = ship.velocity.x + input_velocity.x * player_ship_stats.acceleration * time_increment(false)
	ship.velocity.y = ship.velocity.y + input_velocity.y * player_ship_stats.acceleration * time_increment(false)

	if ship.velocity.x > 0 then
		ship.velocity.x = math.max(0, ship.velocity.x - player_ship_stats.drag * time_increment(false))
	else
		ship.velocity.x = math.min(0, ship.velocity.x + player_ship_stats.drag * time_increment(false))
	end
	if ship.velocity.y > 0 then
		ship.velocity.y = math.max(0, ship.velocity.y - player_ship_stats.drag * time_increment(false))
	else
		ship.velocity.y = math.min(0, ship.velocity.y + player_ship_stats.drag * time_increment(false))
	end

	local velocity_mag = get_mag(ship.velocity)
	if velocity_mag > player_ship_stats.max_speed then
		local normalized_vel = normalize(ship.velocity)
		ship.velocity.x = normalized_vel.x * player_ship_stats.max_speed
		ship.velocity.y = normalized_vel.y * player_ship_stats.max_speed
	elseif velocity_mag < 0.01 then
		ship.velocity = {x = 0, y = 0}
	end
	--print("input: hori:"..controls.held_hori.." vert:"..controls.held_vert.." x:"..input_velocity.x.." y:"..input_velocity.y.." velocity: x:"..ship.velocity.x.." y:"..ship.velocity.y)
end

local function update_player_weapons(ship, mouse_vector)
	local firing = controls.held_fire
	local dt = time_increment(false)
	for _, weapon in ipairs(ship.weapons) do
		weapon.current_cooldown = math.max(0, weapon.current_cooldown - dt)
		if weapon.current_cooldown <= 0 and firing and weapon.beam and not weapon.beam_active then
			local new_pos = get_position_offset_angle(ship.pos, ship.angle, weapon.pos_offset)
			local new_end_pos = {
				x = new_pos.x + 2000 * math.cos(math.rad(ship.angle)),
				y = new_pos.y + 2000 * math.sin(math.rad(ship.angle))
			}
			local template  = weapon.template
			local new_projectile = {
				beam = true,
				type = object_types.player_projectile,
				pos = new_pos,
				pos_end = new_end_pos,
				velocity = {x = 0, y = 0},
				angle = ship.angle,
				beam_width = template.collider_radius,
				damage = template.damage,
				health = 1,
				tick_time = 0.1,
				colour = template.colour,
			}
			if template.follow_up then
				new_projectile.follow_up = template.follow_up
			end
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			weapon.beam_active = new_projectile
			table.insert(player_projectiles, new_projectile)
		elseif weapon.current_cooldown <= 0 and firing and weapon.teleport then
			local new_pos = add_vectors(ship.pos, mouse_vector)
			local template = weapon.template
			local new_projectile = {
				type = object_types.player_projectile,
				pos = new_pos,
				velocity = {x = 0, y = 0},
				angle = ship.angle,
				collider_radius = template.collider_radius,
				damage = template.damage,
				health = 1,
				image = template.image,
				current_distance = 0,
				life_distance = 2000,
				hit_sound = template.hit_sound,
			}
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			if template.trigger_radius then
				new_projectile.trigger_radius = template.trigger_radius
				new_projectile.trigger_time = template.trigger_time
			end
			if template.home_time then
				new_projectile.home_time = template.home_time
			end
			if template.explosion_image_name then
				new_projectile.explosion_image_name = template.explosion_image_name
				new_projectile.explosion_sound = template.explosion_sound
			end
			--print("fire bomb at x:"..new_pos.x.." y:"..new_pos.y)
			table.insert(player_projectiles, new_projectile)
			weapon.current_cooldown = weapon.cooldown
		elseif weapon.current_cooldown <= 0 and firing then
			local new_pos = get_position_offset_angle(ship.pos, ship.angle, weapon.pos_offset)
			local template = weapon.template
			for i = 1, weapon.shots do
				local aim_angle = ship.angle
				if weapon.accuracy and weapon.accuracy ~= 0 then
					local r = (math.random() * 2 * weapon.accuracy) - weapon.accuracy
					aim_angle = aim_angle + r
				end
				local new_velocity = get_velocity_vector(template.speed, math.rad(aim_angle))
				local new_projectile = {
					type = object_types.player_projectile,
					pos = new_pos,
					velocity = add_vectors(scale_vector(ship.velocity, 0.25), new_velocity),
					angle = aim_angle,
					collider_radius = template.collider_radius,
					damage = template.damage,
					health = 1,
					image = template.image,
					current_distance = 0,
					life_distance = 2000,
					hit_sound = template.hit_sound,
				}
				if template.spin then
					new_projectile.spin = template.spin
				end
				if template.firing_sound then
					Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
				end
				if template.trigger_radius then
					new_projectile.trigger_radius = template.trigger_radius
					new_projectile.trigger_time = template.trigger_time
				end
				if template.explosion_image_name then
					new_projectile.explosion_image_name = template.explosion_image_name
					new_projectile.explosion_sound = template.explosion_sound
				end
				if weapon.home_time then
					new_projectile.home_time = weapon.home_time
				end
				table.insert(player_projectiles, new_projectile)
			end
			weapon.current_cooldown = weapon.cooldown
		end
		if weapon.beam_active then
			weapon.beam_active.pos = get_position_offset_angle(ship.pos, ship.angle, weapon.pos_offset)
			weapon.beam_active.pos_end = {
				x = weapon.beam_active.pos.x + 2000 * math.cos(math.rad(ship.angle)),
				y = weapon.beam_active.pos.y + 2000 * math.sin(math.rad(ship.angle))
			}
			weapon.beam_active.angle = ship.angle
			weapon.beam_active.tick_time = math.max(0, weapon.beam_active.tick_time - dt)
			if not firing then
				weapon.beam_active.health = 0
				weapon.beam_active = nil
			end
			weapon.current_cooldown = weapon.cooldown
		end
	end
end

local function update_player_abilities(ship)
end

local function update_enemy_velocity(ship, target_pos, target_velocity, time, linear)
	if time < 0.001 then 
		ship.pos = target_pos
		ship.velocity = target_velocity
	elseif linear then
		--print("move_linear")
		local distance_x = target_pos.x - ship.pos.x
		local distance_y = target_pos.y - ship.pos.y
		ship.velocity.x = distance_x / time
		ship.velocity.y = distance_y / time
	else
		local omega = 4.0 / time
		local Kp = omega * omega 
		local Kd = 2.0 * omega 

		local dx = target_pos.x - ship.pos.x
		local dy = target_pos.y - ship.pos.y
		
		local dvx = target_velocity.x - ship.velocity.x
		local dvy = target_velocity.y - ship.velocity.y

		local accel_x = (dx * Kp) + (dvx * Kd)
		local accel_y = (dy * Kp) + (dvy * Kd)

		ship.velocity.x = ship.velocity.x + (accel_x * time_increment(false))
		ship.velocity.y = ship.velocity.y + (accel_y * time_increment(false))
	end
	--print("enemy velocity: x:"..ship.velocity.x.." y:"..ship.velocity.y.." target_pos: x:"..target_pos.x.." y:"..target_pos.y.." target_velocity: x:"..target_velocity.x.." y:"..target_velocity.y.." time:"..time)
end

local function update_enemy_angle(ship, target_angle, target_velocity, time, linear, set)
	if time < 0.001 then time = 0.001 end
	local angle_error = angle_diff(ship.angle, target_angle)
	if set then
		ship.angle = target_angle
		ship.angular_velocity = 0
	elseif linear then
		local required_turn_rate = angle_error / time
		local move_step = required_turn_rate * time_increment(false)
		if math.abs(angle_error) <= math.abs(move_step) then
			ship.angle = target_angle
			required_turn_rate = move_step
		else
			ship.angle = ship.angle + move_step
		end
		ship.angular_velocity = required_turn_rate
	else
		local omega = 4.0 / time
		local Kp = omega * omega
		local Kd = 2.0 * omega
		
		ship.angular_velocity = ship.angular_velocity or 0 
		
		local angular_velocity_error = target_velocity - ship.angular_velocity 

		local alpha = (angle_error * Kp) + (angular_velocity_error * Kd)

		ship.angular_velocity = ship.angular_velocity + (alpha * time_increment(false))
		
		ship.angle = ship.angle + (ship.angular_velocity * time_increment(false))
	end
	if ship.angle > 180 then
		ship.angle = ship.angle - 360
	elseif ship.angle < -180 then
		ship.angle = ship.angle + 360
	end
end

local function select_new_sequence(ship, current_sequence)
	local r = math.random(#current_sequence.transfer_sequences)
	return current_sequence.transfer_sequences[r]
end

local function set_new_move(ship, move, index)
	local new_move = {index = index, time = move.time, linear = move.linear, linear_angle = move.linear_angle, set_angle = move.set_angle}
	if not move.track then
		if move.relative then
			new_move.pos = {x = player_ship.pos.x + move.x, y = player_ship.pos.y + move.y}
		else
			new_move.pos = {x = ship.pos.x + move.x, y = ship.pos.y + move.y}
		end
	else
		new_move.track = true
		new_move.pos = {x = move.x, y = move.y}
	end
	if not move.track_angle then
		if move.relative_angle then
			new_move.angle = move.angle --do something else
		else
			new_move.angle = move.angle
		end
	else
		new_move.track_angle = true
		new_move.angle = move.angle
	end

	--print("Set new move: x:"..new_move.pos.x.." y:"..new_move.pos.y.." i:"..new_move.index.." t:"..new_move.time)
	return new_move
end

local function reset_enemy_ship_sequence(ship)
	if not ship.current_sequence then
		local r = math.random(#enemy_sequences)
		ship.current_sequence = enemy_sequences[r]
	end
	ship.current_sequence = select_new_sequence(ship, ship.current_sequence)
	--print("set new sequence reset"..tostring(ship.current_sequence.name).." "..tostring(ship.current_sequence.duration))
	ship.sequence_time = 0
	ship.current_move = nil
	ship.current_attack = 1
end

local function perform_enemy_attack(ship, attack)
	local source_pos = ship.pos
	local source_angle = ship.angle
	if attack.source_pos == source_types.player then 
		source_pos = player_ship.pos
	elseif attack.source_pos == source_types.world then
		source_pos = {x = 0, y = 0}
	end
	if attack.aim_pos == aim_types.player then
		source_angle = get_angle_between_points(source_pos, player_ship.pos)
	elseif attack.aim_pos == aim_types.player_ahead then
		--do something
	elseif attack.aim_pos == aim_types.world then
		source_angle = 0
	end
	for _, projectile in ipairs(attack.projectiles) do
		local template = projectile.template
		if template.type == projectile_types.laser then
			local new_pos = get_position_offset_angle(source_pos, source_angle, projectile.pos_offset)
			local new_velocity = get_velocity_vector(template.speed, math.rad(source_angle + projectile.angle_offset))
			local new_projectile = {
				type = object_types.enemy_projectile,
				pos = new_pos,
				velocity = new_velocity,
				angle = normalize_angle(source_angle + projectile.angle_offset),
				collider_radius = template.collider_radius,
				damage = template.damage,
				health = 1,
				image = template.image,
				current_distance = 0,
				life_distance = projectile.travel_distance,
				hit_sound = template.hit_sound,
			}
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			table.insert(enemy_projectiles, new_projectile)
		elseif projectile.template.type == projectile_types.beam then
			local new_pos = get_position_offset_angle(source_pos, source_angle, projectile.pos_offset)
			local new_end_pos = {
				x = new_pos.x + 2000 * math.cos(math.rad(source_angle + projectile.angle_offset)),
				y = new_pos.y + 2000 * math.sin(math.rad(source_angle + projectile.angle_offset))
			}
			local new_projectile = {
				beam = true,
				type = object_types.enemy_projectile,
				pos = new_pos,
				pos_offset = projectile.pos_offset,
				pos_end = new_end_pos,
				velocity = {x = 0, y = 0},
				angle = normalize_angle(source_angle + projectile.angle_offset),
				angle_offset = projectile.angle_offset,
				beam_width = template.collider_radius,
				damage = template.damage,
				tick_time = 0.1,
				colour = template.colour,
				health = projectile.life_time,
			}
			if template.follow_up then
				new_projectile.follow_up = template.follow_up
			end
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			if projectile.track then
				table.insert(ship.active_beams, new_projectile)
			end
			table.insert(enemy_projectiles, new_projectile)
		elseif projectile.template.type == projectile_types.mine then
			local new_pos = get_position_offset_angle(source_pos, source_angle, projectile.pos_offset)
			local new_projectile = {
				type = object_types.enemy_projectile,
				pos = new_pos,
				velocity = {x = 0, y = 0},
				angle = normalize_angle(source_angle + projectile.angle_offset),
				damage = template.damage,
				health = 1,
				image = template.image,
				current_distance = 0,
				life_distance = projectile.travel_distance,
				hit_sound = template.hit_sound,
			}
			if template.collider_radius then
				new_projectile.collider_radius = template.collider_radius
			end
			if template.trigger_radius then
				new_projectile.trigger_radius = template.trigger_radius
				new_projectile.trigger_time = template.trigger_time
			end
			if template.explosion_image_name then
				new_projectile.explosion_image_name = template.explosion_image_name
			end
			if template.explosion_sound then
				new_projectile.explosion_sound = template.explosion_sound
			end
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			table.insert(enemy_projectiles, new_projectile)
		end
	end
end

local function update_enemy_ship(ship)
	local target_pos = {x = ship.pos.x, y = ship.pos.y}
	local target_velocity = {x = 0, y = 0}
	local target_angle = ship.angle
	local target_angular_velocity = 0
	local linear = false
	local set_angle = false
	local linear_angle = false
	local travel_time = 0
	if #ship.health_thresholds > 0 and ship.health <= ship.health_thresholds[#ship.health_thresholds].health then
		if ship.health_thresholds[#ship.health_thresholds].i_frames then
			ship.i_frames = ship.health_thresholds[#ship.health_thresholds].i_frames
		end
		create_explosion(ship.pos, damage_explosion, damage_explosion_sound)

		ship.current_sequence = ship.health_thresholds[#ship.health_thresholds].sequence
		if #ship.active_beams > 0 then
			for _, beam in ipairs(ship.active_beams) do
				beam.health = 0
			end
		end
		--print("set new sequence threshold"..ship.current_sequence.name.." "..tostring(ship.current_sequence.duration))
		ship.sequence_time = 0
		ship.current_move = nil
		ship.current_attack = 1
		ship.health_thresholds[#ship.health_thresholds] = nil
	end
	if ship.i_frames and ship.i_frames <= 0 then
		ship.i_frames = nil
	end
	if ship.current_sequence then
		ship.sequence_time = ship.sequence_time + time_increment(false)
		--print("sequence_time:"..ship.sequence_time.." sequence:"..tostring(ship.current_sequence.name).." duration:"..tostring(ship.current_sequence.duration))
		if ship.sequence_time >= ship.current_sequence.duration then
			reset_enemy_ship_sequence(ship)
		elseif ship.current_move then --Has current move
			if ship.sequence_time >= ship.current_move.time then
				ship.pos = ship.current_move.pos
				ship.velocity = target_velocity
				if #ship.current_sequence.move_sequence > ship.current_move.index then
					ship.current_move = set_new_move(ship, ship.current_sequence.move_sequence[ship.current_move.index + 1], ship.current_move.index + 1)
				end
			else --update
				travel_time = ship.current_move.time - ship.sequence_time
				if ship.current_move.track then
					target_pos = add_vectors(player_ship.pos, ship.current_move.pos)
					if travel_time < 0.1 then
						ship.current_move.pos = target_pos
						ship.current_move.track = false
					end
				else
					target_pos = ship.current_move.pos
				end
				linear = ship.current_move.linear
				if ship.current_move.track_angle then
					target_angle = get_angle_between_points(ship.pos, player_ship.pos)
					if travel_time < 0.1 then
						ship.current_move.angle = target_angle
						ship.current_move.track_angle = false
					end
				else
					target_angle = ship.current_move.angle
				end
				set_angle = ship.current_move.set_angle
				linear_angle = ship.current_move.linear_angle
			end
		else --First move new sequence
			ship.current_move = set_new_move(ship, ship.current_sequence.move_sequence[1], 1)
		end
		--print("ship.current_attack:"..tostring(ship.current_attack).." #ship.current_sequence.attack_sequence:"..tostring(#ship.current_sequence.attack_sequence))
		if ship.current_attack <= #ship.current_sequence.attack_sequence then
			local current_attack = ship.current_sequence.attack_sequence[ship.current_attack]
			if ship.sequence_time >= current_attack.time then
				perform_enemy_attack(ship, current_attack.attack)
				ship.current_attack = ship.current_attack + 1
			end
		end
	else
		reset_enemy_ship_sequence(ship)
	end
	local remove_beam = nil
	for i, beam in ipairs(ship.active_beams) do
		beam.pos = get_position_offset_angle(ship.pos, ship.angle + beam.angle_offset, beam.pos_offset)
		beam.pos_end = {
			x = beam.pos.x + 2000 * math.cos(math.rad(ship.angle + beam.angle_offset)),
			y = beam.pos.y + 2000 * math.sin(math.rad(ship.angle + beam.angle_offset))
		}
		beam.angle = ship.angle

		if beam.health <= 0 then
			remove_beam = i
		end
	end
	if remove_beam then
		table.remove(ship.active_beams, remove_beam)
	end
	update_enemy_velocity(ship, target_pos, target_velocity, travel_time, linear)
	update_enemy_angle(ship, target_angle, target_angular_velocity, travel_time, linear_angle, set_angle)
end

local function check_collisions(object, colliders_list)
	local new_pos = {}
	new_pos.x = object.pos.x + object.velocity.x * time_increment(false)
	new_pos.y = object.pos.y + object.velocity.y * time_increment(false)
	local object_collider = object.collider_radius
	local remove_object = nil
	local vunerable = (not (object.i_frames and object.i_frames > 0))
	for i, projectile in ipairs(colliders_list) do
		if projectile.collider_radius then
			local projectile_collider = projectile.collider_radius
			if vunerable and get_distance(new_pos, projectile.pos) <= object_collider + projectile_collider then
				damage_object(object, projectile.damage)
				if projectile.hit_sound then
					Hyperspace.Sounds:PlaySoundMix(projectile.hit_sound, -1, false)
				end
				local temp_remove = damage_object(projectile, 1)
				if temp_remove then remove_object = i end
			end
		end
		if projectile.trigger_radius and not projectile.armed_time then
			local projectile_collider = projectile.trigger_radius
			if get_distance(new_pos, projectile.pos) <= object_collider + projectile_collider then
				projectile.armed_time = projectile.trigger_time
				--print("trigger projectile")
			end
		end
		if vunerable and projectile.beam_width and projectile.tick_time <= 0 then
			local beam_vector_x = projectile.pos_end.x - projectile.pos.x
			local beam_vector_y = projectile.pos_end.y - projectile.pos.y

			local object_vector_x = new_pos.x - projectile.pos.x
			local object_vector_y = new_pos.y - projectile.pos.y

			local dot_product = object_vector_x * beam_vector_x + object_vector_y * beam_vector_y
			local beam_square = beam_vector_x * beam_vector_x + beam_vector_y * beam_vector_y

			local t = 0
			if beam_square ~= 0 then
				t = dot_product / beam_square
			end
			t = math.max(0, math.min(1, t))

			local closest_x = projectile.pos.x + t * beam_vector_x
			local closest_y = projectile.pos.y + t * beam_vector_y

			required_dist = object_collider + (projectile.beam_width/2)
			local actual_dist = get_distance(new_pos, {x = closest_x, y = closest_y})
			if actual_dist <= required_dist then
				damage_object(object, projectile.damage)
				projectile.tick_time = 0.1
				if projectile.hit_sound then
					Hyperspace.Sounds:PlaySoundMix(projectile.hit_sound, -1, false)
				end
			end
		end
	end
	if remove_object then
		table.remove(colliders_list, remove_object)
	end
end

local function update_drone_velocity(drone, target)
	local time = 2
	local distance_x = target.x - drone.pos.x
	local distance_y = target.y - drone.pos.y
	if get_distance(drone.pos, target) > 100 then
		drone.velocity.x = distance_x / time
		drone.velocity.y = distance_y / time
	else
		drone.velocity.x = -1 * distance_x / time
		drone.velocity.y = -1 * distance_y / time
	end
end

local function resolve_drone_collision(drone)
	for _, other_drone in ipairs(player_drones) do
		if other_drone ~= drone then
			
			local dist = get_distance(drone.pos, other_drone.pos)
			local min_safe_distance = drone.collider_radius + other_drone.collider_radius
			
			if dist == 0 then
				drone.pos.x = drone.pos.x + math.random(-20, 20)
				drone.pos.y = drone.pos.y + math.random(-20, 20)
			elseif dist < min_safe_distance then
				local dx = drone.pos.x - other_drone.pos.x
				local dy = drone.pos.y - other_drone.pos.y
				
				local overlap = min_safe_distance - dist
				
				local normal_x = dx / dist
				local normal_y = dy / dist
				
				local correction_x = normal_x * (overlap / 2.0)
				local correction_y = normal_y * (overlap / 2.0)
				
				drone.pos.x = drone.pos.x + correction_x
				drone.pos.y = drone.pos.y + correction_y
				
				local vrel_x = drone.velocity.x - other_drone.velocity.x
				local vrel_y = drone.velocity.y - other_drone.velocity.y
				
				local vel_along_normal = (vrel_x * normal_x) + (vrel_y * normal_y)

				if vel_along_normal < 0 then
					local impulse = -vel_along_normal
					
					drone.velocity.x = drone.velocity.x + impulse * normal_x
					drone.velocity.y = drone.velocity.y + impulse * normal_y
				end
			end
		end
	end
end

local function update_drone_angle(drone, target)
	drone.angle = get_angle_between_points(drone.pos, target)
end

local add_projectiles = {}

local function update_object(object)
	local remove_object = nil
	if object.type == object_types.player then
		update_player_velocity(object)
		local mouse_pos = Hyperspace.Mouse.position
		local relative_pos = {x = 640, y = 360}
		local mouse_angle = get_angle_between_points(relative_pos, mouse_pos)
		object.angle = move_angle_to(object.angle, mouse_angle, player_ship_stats.rotation_speed * time_increment(false))
		check_collisions(object, enemy_projectiles)
		local mouse_vector = sub_vectors(mouse_pos, relative_pos)
		update_player_weapons(object, mouse_vector)
		update_player_abilities(object)
	elseif object.type == object_types.enemy then
		update_enemy_ship(object)
		check_collisions(object, player_projectiles)
		if object.health <= 0 then
			remove_object = true
		end
	elseif (object.type == object_types.player_projectile or object.type == object_types.enemy_projectile) then
		if current_distance then
			object.current_distance = object.current_distance + get_mag(object.velocity) * time_increment(false)
			if object.current_distance >= object.life_distance then
				remove_object = true
			end
		end
		if object.beam and object.type == object_types.enemy_projectile then
			object.tick_time = math.max(0, object.tick_time - time_increment(false))
			object.health = math.max(0, object.health - time_increment(false))
		end
		if object.beam and object.health <= 0 then
			remove_object = true
			if object.follow_up then
				table.insert(add_projectiles, {pos = object.pos, angle = object.angle, template = object.follow_up, type = object.type})
			end
		end
		if object.armed_time then
			object.armed_time = math.max(0, object.armed_time - time_increment(false))
		end
		if object.armed_time and object.armed_time <= 0 then
			if object.explosion_image_name then
				create_explosion(object.pos, object.explosion_image_name, object.explosion_sound)
			end
			if object.type == object_types.player_projectile then 
				for _, ship in ipairs(enemy_ships) do
					create_explosion_collision(ship, object.pos, object.trigger_radius)
				end
			else
				create_explosion_collision(player_ship, object.pos, object.trigger_radius, object.damage)
			end
			remove_object = true
		end
	elseif object.type == object_types.player_drone then
		local target = nil
		for _, ship in ipairs(enemy_ships) do
			if (not target) or get_distance(object.pos, ship.pos) < get_distance(object.pos, target.pos) then
				target = ship
			end
		end
		if target then
			update_drone_velocity(object, target.pos)
			update_drone_angle(object, target.pos)
		else
			update_drone_velocity(object, player_ship.pos)
			local mouse_pos = Hyperspace.Mouse.position
			local mouse_pos_relative = {
				x = mouse_pos.x + player_ship.pos.x - 640,
				y = mouse_pos.y + player_ship.pos.y - 360
			}
			update_drone_angle(object, mouse_pos_relative)
		end
		resolve_drone_collision(object)
		object.current_cooldown = math.max(0, object.current_cooldown - time_increment(false))
		if object.current_cooldown <= 0 and #enemy_ships > 0 then
			object.current_cooldown = object.cooldown
			local template = object.template
			local new_velocity = get_velocity_vector(template.speed, math.rad(object.angle))
			local new_projectile = {
				type = object_types.player_projectile,
				pos = {x = object.pos.x, y = object.pos.y},
				velocity = new_velocity,
				angle = object.angle,
				collider_radius = template.collider_radius,
				damage = template.damage,
				health = 1,
				image = template.image,
				current_distance = 0,
				life_distance = 2000,
				hit_sound = template.hit_sound,
			}
			if template.firing_sound then
				Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
			end
			table.insert(player_projectiles, new_projectile)
		end
	end
	if object.i_frames then
		object.i_frames = math.max(0, object.i_frames - time_increment(false))
	end
	if object.spin then
		object.angle = normalize_angle(object.angle + object.spin * time_increment(false))
	end

	object.pos.x = object.pos.x + object.velocity.x * time_increment(false)
	object.pos.y = object.pos.y + object.velocity.y * time_increment(false)
	return remove_object
end

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local commandGui = Hyperspace.App.gui
	if Hyperspace.playerVariables[active_var] == 1 then
		if Hyperspace.App.menu.bOpen or Hyperspace.App.menu.shipBuilder.bOpen then
			return
		end
		if not commandGui.event_pause then
			start_mode()
		end
		update_object(player_ship)

		local remove_ship_enemy = nil
		for i, object in ipairs(enemy_ships) do
			local temp_remove = update_object(object)
			if temp_remove then remove_ship_enemy = i end
			--print("type:"..object.type.." position: x:"..object.pos.x.." y:"..object.pos.y.." velocity: x:"..object.velocity.x.." y:"..object.velocity.y)
		end
		if remove_ship_enemy then
			table.remove(enemy_ships, remove_ship_enemy)
		end

		local remove_object_enemy = {}
		for i, object in ipairs(enemy_projectiles) do
			local temp_remove = update_object(object)
			if temp_remove then table.insert(remove_object_enemy, i) end
			--print("type:"..object.type.." position: x:"..object.pos.x.." y:"..object.pos.y.." velocity: x:"..object.velocity.x.." y:"..object.velocity.y)
		end
		if #remove_object_enemy > 0 then
			for i = #remove_object_enemy, 1, -1 do
				table.remove(enemy_projectiles, remove_object_enemy[i])
			end
		end

		local remove_object_player = {}
		for i, object in ipairs(player_projectiles) do
			local temp_remove = update_object(object)
			if temp_remove then table.insert(remove_object_player, i) end
			--print("type:"..object.type.." position: x:"..object.pos.x.." y:"..object.pos.y.." velocity: x:"..object.velocity.x.." y:"..object.velocity.y)
		end
		if #remove_object_player > 0 then
			for i = #remove_object_player, 1, -1 do
				table.remove(player_projectiles, remove_object_player[i])
			end
		end

		local remove_drone_player = nil
		for i, object in ipairs(player_drones) do
			local temp_remove = update_object(object)
			if temp_remove then remove_drone_player = i end
		end
		if remove_drone_player then
			table.remove(player_drones, remove_drone_player)
		end

		local remove_explosion = {}
		for i, explosion in ipairs(explosion_list) do
			explosion:Update()
			if explosion:Done() then
				table.insert(remove_explosion, i)
			end
		end
		if #remove_explosion > 0 then
			for i = #remove_explosion, 1, -1 do
				table.remove(explosion_list, remove_explosion[i])
			end
		end

		if #add_projectiles > 0 then
			for _, proj_table in ipairs(add_projectiles) do
				--print("add proj")
				local template = proj_table.template
				if template.type == projectile_types.laser then
					--print("add laser")
					local new_velocity = get_velocity_vector(template.speed, math.rad(proj_table.angle))
					local new_projectile = {
						type = object_types.enemy_projectile,
						pos = proj_table.pos,
						velocity = new_velocity,
						angle = proj_table.angle,
						collider_radius = template.collider_radius,
						damage = template.damage,
						health = 1,
						image = template.image,
						current_distance = 0,
						life_distance = 2000,
						hit_sound = template.hit_sound,
					}
					if template.firing_sound then
						Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
					end
					table.insert(enemy_projectiles, new_projectile)
				elseif template.type == projectile_types.beam then
					--print("add beam")
					local new_end_pos = {
						x = proj_table.pos.x + 2000 * math.cos(math.rad(proj_table.angle)),
						y = proj_table.pos.y + 2000 * math.sin(math.rad(proj_table.angle))
					}
					local new_projectile = {
						beam = true,
						type = object_types.enemy_projectile,
						pos = proj_table.pos,
						pos_offset = {x = 0, y = 0},
						pos_end = new_end_pos,
						velocity = {x = 0, y = 0},
						angle = proj_table.angle,
						angle_offset = 0,
						beam_width = template.collider_radius,
						damage = template.damage,
						tick_time = 0.1,
						colour = template.colour,
						health = 1,
					}
					if template.firing_sound then
						Hyperspace.Sounds:PlaySoundMix(template.firing_sound, -1, false)
					end
					table.insert(enemy_projectiles, new_projectile)
				end
			end
			add_projectiles = {}
		end
	end
end)

local function render_object(object)
	if object.image then
		local colour = Graphics.GL_Color(1, 1, 1, 1)
		if object.armed_time and (object.armed_time * 20) % 2 >= 1 then
			colour = Graphics.GL_Color(1, 0.25, 0.25, 1)
		end
		if object.trigger_radius then
			Graphics.CSurface.GL_DrawCircle(
				object.pos.x,
				object.pos.y,
				object.trigger_radius,
				Graphics.GL_Color(1, 0.25, 0.25, 0.5)
				)
		end
		--[[if object.collider_radius then
			Graphics.CSurface.GL_DrawCircle(
				object.pos.x,
				object.pos.y,
				object.collider_radius,
				Graphics.GL_Color(0.25, 0.25, 0.25, 0.5)
				)
		end]]
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(object.pos.x, object.pos.y, 0)
		Graphics.CSurface.GL_Rotate(object.angle, 0, 0, 1)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(object.image, colour)
		Graphics.CSurface.GL_PopMatrix()
	elseif object.beam_width then
		Graphics.CSurface.GL_DrawLine(
			object.pos.x,
			object.pos.y,
			object.pos_end.x,
			object.pos_end.y,
			object.beam_width,
			object.colour
			)
		Graphics.CSurface.GL_DrawLine(
			object.pos.x,
			object.pos.y,
			object.pos_end.x,
			object.pos_end.y,
			object.beam_width/2,
			object.colour
			)
	end
end

local function render_background_layer(layer, player_x, player_y)
	local screen_w = 1280
	local screen_h = 720
	
	local parallax_x = player_x * layer.parallax_scale
	local parallax_y = player_y * layer.parallax_scale
	
	local view_center_x = parallax_x
	local view_center_y = parallax_y

	local center_tile_x = math.floor(view_center_x / layer.width) * layer.width
	local center_tile_y = math.floor(view_center_y / layer.height) * layer.height
	
	local half_tiles_w = math.ceil((screen_w / 2) / layer.width) + 1
	local half_tiles_h = math.ceil((screen_h / 2) / layer.height) + 1

	local start_x_index = -half_tiles_w
	local end_x_index = half_tiles_w
	local start_y_index = -half_tiles_h
	local end_y_index = half_tiles_h
	
	for tile_x_index = start_x_index, end_x_index do
		for tile_y_index = start_y_index, end_y_index do
			Graphics.CSurface.GL_PushMatrix()
			
			-- Calculate the tile's world position relative to the center tile
			local tile_world_x = center_tile_x + (tile_x_index * layer.width)
			local tile_world_y = center_tile_y + (tile_y_index * layer.height)
			
			-- Calculate the position to render the tile on the screen (in pixels)
			local pos_x = tile_world_x - parallax_x -- Current world position minus parallax offset
			local pos_y = tile_world_y - parallax_y
			
			-- Translate: Center of screen (640, 360) + calculated position
			Graphics.CSurface.GL_Translate(
				math.floor(640 + pos_x),
				math.floor(360 + pos_y),
				0
			)
			
			-- Render the tile
			Graphics.CSurface.GL_RenderPrimitiveWithColor(layer.image, Graphics.GL_Color(1, 1, 1, 1))
			
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end

local player_health_x = 20
local player_health_y = 20
local player_health_width = 320
local player_health_height = 25
local function render_player_ui()
	local ship = player_ship
	local x = player_health_x
	local y = player_health_y

	local health_percent = ship.health / ship.max_health
	local width = health_percent * player_health_width

	local light = Graphics.GL_Color(1, 1, 1, 1)
	local dark = Graphics.GL_Color(10/255, 22/255, 33/255, 1)
	local red = Graphics.GL_Color(1, 60/255, 60/255, 1)
	if ship.i_frames and ship.i_frames > 0 then
		red = Graphics.GL_Color(120/255, 120/255, 140/255, 1)
	end
	Graphics.CSurface.GL_DrawRect(x - 2, y - 2, player_health_width + 4, player_health_height + 4, light)
	Graphics.CSurface.GL_DrawRect(x - 1, y - 1, player_health_width + 2, player_health_height + 2, dark)
	Graphics.CSurface.GL_DrawRect(x, y, width, player_health_height, red)
	Graphics.freetype.easy_printCenter(14, player_health_x + player_health_width / 2, y - 4, math.floor(ship.health).."/"..math.floor(ship.max_health))
end

local enemy_health_x = 640
local enemy_health_y = 700
local enemy_health_spacing = 35
local enemy_health_width = 640
local enemy_health_height = 25
local function render_enemy_ui()
	for i, ship in ipairs(enemy_ships) do
		local x = enemy_health_x - enemy_health_width / 2
		local y = enemy_health_y - enemy_health_height - enemy_health_spacing * i

		local health_percent = ship.health / ship.max_health
		local width = health_percent * enemy_health_width

		local light = Graphics.GL_Color(1, 1, 1, 1)
		local dark = Graphics.GL_Color(10/255, 22/255, 33/255, 1)
		local red = Graphics.GL_Color(1, 60/255, 60/255, 1)
		if ship.i_frames then
			red = Graphics.GL_Color(120/255, 120/255, 140/255, 1)
		end
		Graphics.CSurface.GL_DrawRect(x - 2, y - 2, enemy_health_width + 4, enemy_health_height + 4, light)
		Graphics.CSurface.GL_DrawRect(x - 1, y - 1, enemy_health_width + 2, enemy_health_height + 2, dark)
		Graphics.CSurface.GL_DrawRect(x, y, width, enemy_health_height, red)
		for _, threshold in ipairs(ship.health_thresholds) do
			local h_p = threshold.health / ship.max_health
			local x_t = h_p * enemy_health_width
			Graphics.CSurface.GL_DrawRect(x + x_t, y, 1, enemy_health_height, dark)
		end
		Graphics.freetype.easy_printCenter(14, enemy_health_x, y - 4, math.floor(ship.health).."/"..math.floor(ship.max_health))
	end
end

--Render Game
script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() end, function() 
	if Hyperspace.playerVariables[active_var] == 1 then
		if Hyperspace.App.menu.bOpen or Hyperspace.App.menu.shipBuilder.bOpen then
			return
		end
		Graphics.CSurface.GL_RenderPrimitiveWithColor(back_images[back_image_index], Graphics.GL_Color(1, 1, 1, 1))

		for _, layer in ipairs(background_layers) do
			render_background_layer(layer, player_ship.pos.x, player_ship.pos.y)
		end

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(640 - player_ship.pos.x, 360 - player_ship.pos.y, 0)

		for _, object in ipairs(player_projectiles) do
			render_object(object)
		end
		if player_ship then
			render_object(player_ship)
		end
		for _, object in ipairs(enemy_projectiles) do
			render_object(object)
		end
		for _, object in ipairs(enemy_ships) do
			render_object(object)
		end
		for _, object in ipairs(player_drones) do
			render_object(object)
		end
		for _, explosion in ipairs(explosion_list) do
			explosion:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		end
		Graphics.CSurface.GL_PopMatrix()

		for _, layer in ipairs(foreground_layers) do
			render_background_layer(layer, player_ship.pos.x, player_ship.pos.y)
		end

		--render UI
		render_player_ui()
		render_enemy_ui()
	end
end)


script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
	--print("pressed key: "..tostring(key))
	if Hyperspace.playerVariables[active_var] == 1 then
		if key == Hyperspace.playerVariables[controls.up_key_var] then
			controls.held_vert = -1
			controls.held_up = true
		elseif key == Hyperspace.playerVariables[controls.down_key_var] then
			controls.held_vert = 1
			controls.held_down = true
		elseif key == Hyperspace.playerVariables[controls.left_key_var] then
			controls.held_hori = -1
			controls.held_left = true
		elseif key == Hyperspace.playerVariables[controls.right_key_var] then
			controls.held_hori = 1
			controls.held_right = true
		end

		if key == 47 then --/
			end_mode()
		elseif key == 101 then
			spawn_enemy()
		end
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.ON_KEY_UP, function(key)
	if Hyperspace.playerVariables[active_var] == 1 then
		if key == Hyperspace.playerVariables[controls.up_key_var] and controls.held_vert == -1 then
			controls.held_up = false
			if controls.held_down then
				controls.held_vert = 1
			else
				controls.held_vert = 0
			end
		elseif key == Hyperspace.playerVariables[controls.up_key_var] and controls.held_up then
			controls.held_up = false
		elseif key == Hyperspace.playerVariables[controls.down_key_var] and controls.held_vert == 1 then
			controls.held_down = false
			if controls.held_up then
				controls.held_vert = -1
			else
				controls.held_vert = 0
			end
		elseif key == Hyperspace.playerVariables[controls.down_key_var] and controls.held_down then
			controls.held_down = false
		elseif key == Hyperspace.playerVariables[controls.left_key_var] and controls.held_hori == -1 then
			controls.held_left = false
			if controls.held_right then
				controls.held_hori = 1
			else
				controls.held_hori = 0
			end
		elseif key == Hyperspace.playerVariables[controls.left_key_var] and controls.held_left then
			controls.held_left = false
		elseif key == Hyperspace.playerVariables[controls.right_key_var] and controls.held_hori == 1 then
			controls.held_right = false
			if controls.held_left then
				controls.held_hori = -1
			else
				controls.held_hori = 0
			end
		elseif key == Hyperspace.playerVariables[controls.right_key_var] and controls.held_right then
			controls.held_right = false
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x,y)
	if Hyperspace.playerVariables[active_var] == 1 then
		--print("press fire")
		controls.held_fire = true
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_UP, function(x,y)
	if Hyperspace.playerVariables[active_var] == 1 and controls.held_fire then
		--print("release fire")
		controls.held_fire = false
	end
	return Defines.Chain.CONTINUE
end)