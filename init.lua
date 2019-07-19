snowcone = {
	flavors = {}
}

assert(farming.mod and farming.mod == "redo", "'snowcone' has unsatisfied dependencies: farming_redo")

minetest.register_entity("snowcone:syrup", {
	visual = "mesh",
	mesh = "snowcone_syrup.b3d",
	textures = {"snowcone_syrup.png"},
	use_texture_alpha = true,
	visual_size = {x = 9.95, y = 10, z = 9.95},
	pointable = false,
	--selectionbox = {-6 / 16, -4 / 16, -6 / 16, 6 / 16, 7 / 16, 6 / 16},
	collisionbox = {-6 / 16, -4 / 16, -6 / 16, 6 / 16, 7 / 16, 6 / 16},
	on_activate = function(self, data)
		local pos = self.object:get_pos()

		for _, obj in pairs(minetest.get_objects_inside_radius(pos, 0)) do
			if not obj:is_player() and obj:get_luaentity().name == "snowcone:syrup" and obj ~= self.object then
				self.object:remove()
				return
			end
		end

		data = minetest.deserialize(data)
		self.object:set_properties({textures = {data.texture}})
		if data.level then
			self.object:set_animation({x = data.level, y = data.level}, 0)
		end
	end,
	get_staticdata = function(self)
		local anim = self.object:get_animation()
		if anim.range then
			anim = anim.range
		end
		return minetest.serialize({level = anim.x, texture = self.object:get_properties().textures[1]})
	end
})

minetest.register_node("snowcone:container", {
	description = "Empty Syrup Container",
	drawtype = "mesh",
	mesh = "snowcone_container.obj",
	tiles = {
		{
			name = "snowcone_container.png",
			color = "#ffffff"
		}
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	groups = {cracky = 1, snappy = 2, oddly_breakable_by_hand = 2},
	sounds = default.node_sound_glass_defaults(),
	on_rightclick = function(pos, node, clicker, itemstack)
		local meta = minetest.get_meta(pos)
		local current = meta:get_string("flavor")

		local level = meta:get_int("level")
		local oldlevel = level

		local item = itemstack:get_name()
		local color = snowcone.flavors[current]
		if item:match("^snowcone:bucket_syrup_") then
			local imeta = itemstack:get_meta()
			local flavor = item:sub(23)

			if current ~= "" and current ~= flavor then
				return
			end

			meta:set_string("flavor", flavor)

			local add = imeta:get_int("leftover")
			if add == 0 then
				add = 16
			end
			level = level + add

			if level > 64 then
				local leftover = level - 64
				imeta:set_int("leftover", leftover)
				imeta:set_string("description", "Bucket of ".. flavor:gsub("^%l", string.upper) .. " Syrup (" .. leftover .. " servings)")
				level = 64
			else
				itemstack = ItemStack("bucket:bucket_empty")
			end

			color = snowcone.flavors[flavor]
		elseif item == "snowcone:raw" then
			level = level - 1
			oldlevel = level
			meta:set_int("level", level)
			itemstack = ItemStack("snowcone:" .. current)
		elseif item == "bucket:bucket_empty" then
			if level < 16 then
				return
			end
			level = level - 16
			oldlevel = level
			if level < 0 then
				level = 0
			end

			local stack = ItemStack("snowcone:bucket_syrup_" .. current)
			local inv = clicker:get_inventory()
			if itemstack:get_count() == 1 then
				itemstack = stack
			elseif inv:room_for_item("main", stack) then
				itemstack:take_item(1)
				inv:add_item("main", stack)
			else
				return
			end
		else
			return
		end

		meta:set_int("level", level)
		if level == 0 then
			meta:set_string("flavor", "")
		end
		for _, obj in pairs(minetest.get_objects_inside_radius(pos, 0)) do
			if not obj:is_player() and obj:get_luaentity().name == "snowcone:syrup" then
				if level > 0 then
					obj:set_animation({x = oldlevel, y = level}, 15, 0, false)
				else
					obj:remove()
				end
				return itemstack
			end
		end
		if level > 0 then
			local ent =	minetest.add_entity(pos, "snowcone:syrup",	minetest.serialize({texture = "snowcone_syrup.png^[colorize:" .. color .. ":200"}))
			ent:set_animation({x = oldlevel, y = level}, 15, 0, false)
		end
		return itemstack
	end,
	on_destruct = function(pos)
		for _, obj in pairs(minetest.get_objects_inside_radius(pos, 0)) do
			if not obj:is_player() and obj:get_luaentity().name == "snowcone:syrup" then
				obj:remove()
			end
		end
	end,
	can_dig = function(pos)
		local meta = minetest.get_meta(pos)
		return meta:get_int("level") == 0
	end
})

minetest.register_craft({
	output = "snowcone:container",
	recipe = {
		{"default:tin_ingot", "default:tin_ingot", "default:tin_ingot"},
		{"default:glass", "", "default:glass"},
		{"default:tin_ingot", "bucket:bucket_empty", "default:tin_ingot"}
	}
})

function snowcone.register_flavor(flavor, def)
	assert(flavor, "Invalid snowcone flavor.")
	assert(def, "Invalid snowcone definition.")
	def.color = def.color or "#ffffff"
	def.alpha = def.alpha or 200
	snowcone.flavors[flavor] = def.color
	minetest.register_craftitem("snowcone:" .. flavor, {
		description = flavor:gsub("^%l", string.upper) .. " Snow Cone",
		inventory_image = "snowcone_cup.png^(snowcone_ice.png^[colorize:" .. def.color .. ":" .. def.alpha .. ")",
		stack_max = 1,
		on_use = minetest.item_eat(1, "snowcone:cup_1")
	})
	if def.craftitem then
		if type(def.craftitem) ~= "table" then
			def.craftitem = {def.craftitem}
		end
		minetest.register_craftitem("snowcone:bucket_syrup_" .. flavor,	{
			description = "Bucket of " .. flavor:gsub("^%l", string.upper) .. " Syrup",
			inventory_image = "snowcone_bucket.png^(snowcone_bucket_syrup.png^[colorize:" ..
				def.color .. ":" .. def.alpha .. ")",
			stack_max = 1
		})
		for _, item in pairs(def.craftitem) do
			minetest.register_craft({
				output = "snowcone:bucket_syrup_" .. flavor,
				type = "shapeless",
				recipe = {"farming:juicer", "farming:sugar", "farming:sugar", item, item, item, item, "bucket:bucket_empty"},
				replacements = {{"farming:juicer", "farming:juicer"}}
			})
		end
	end
end

minetest.register_craftitem("snowcone:raw",	{
	description = "Snow Cone",
	inventory_image = "snowcone_cup.png^(snowcone_ice.png^[colorize:white:200)",
	stack_max = 1
})

snowcone.register_flavor("strawberry", {
	color = "#db1825",
	craftitem = "ethereal:strawberry"
})

snowcone.register_flavor("watermelon", {
	color = "#e83872",
	craftitem = "farming:melon_slice"
})

snowcone.register_flavor("raspberry", {
	color = "#ed0974",
	craftitem = "farming:raspberries"
})

snowcone.register_flavor("orange", {
	color = "#e67e00",
	craftitem = "ethereal:orange"
})

snowcone.register_flavor("banana", {
	color = "#e8d664",
	craftitem = "ethereal:banana"
})

snowcone.register_flavor("pineapple", {
	color = "#f7f140",
	craftitem = "farming:pineapple_ring"
})

snowcone.register_flavor("blueberry", {
	color = "#4918db",
	craftitem = {"farming:blueberries", "default:blueberries"}
})

snowcone.register_flavor("grape", {
	color = "#680082",
	craftitem = "farming:grapes"
})

for i = 1, 9 do
	minetest.register_node("snowcone:cup_" .. i, {
		description = "Snowcone Cups",
		drawtype = "mesh",
		mesh = "snowcone_cup_stack.obj",
		tiles = {
			"snowcone_blank.png^[lowpart:" .. math.floor((100 / 16) * i) .. ":snowcone_cup_stack.png",
			"[combine:4x36:0," .. 36 - (i * 4) .. "=snowcone_cup_stack_top.png",
			"snowcone_cup_stack_bottom.png"
		},
		selection_box = {
			type = "fixed",
			fixed = {-2 / 16, -8 / 16, -2 / 16, 2 / 16, (8 - (12 - i)) / 16, 2 / 16}
		},
		--[[collision_box = {
		type = "fixed",
		fixed = {-2 / 16, -8 / 16, -2 / 16, 2 / 16, (8 - (12 - i)) / 16, 2 / 16}
	},]]
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		groups = {snappy = 1, not_in_creative_inventory = 1},
		on_punch = function(pos, node, puncher)
			local count = tonumber(node.name:sub(-1))
			local inv = puncher:get_inventory()
			local stack = ItemStack("snowcone:cup_1")
			if inv:room_for_item("main", stack) then
				inv:add_item("main", stack)
				if count > 1 then
					minetest.set_node(pos, {name = "snowcone:cup_" .. count - 1})
				else
					minetest.set_node(pos, {name = "air"})
				end
			end
		end,
		on_rightclick = function(pos, node, clicker, itemstack)
			local count = tonumber(node.name:sub(-1))
			local inv = clicker:get_inventory()
			if itemstack:get_name() == "snowcone:cup_1" then
				if count < 9 then
					itemstack:take_item(1)
					minetest.set_node(pos, {name = "snowcone:cup_" .. count + 1})
				end
			end
			return itemstack
		end
	})

	local recipe = {}
	for c = 1, i do
		recipe[c] = "snowcone:cup_1"
	end

	minetest.register_craft({
		output = "snowcone:cup_" .. i,
		type = "shapeless",
		recipe = recipe
	})
end

minetest.override_item("snowcone:cup_1", {
	description = "Snowcone Cup",
	inventory_image = "snowcone_cup.png",
	groups = {snappy = 1}
})

minetest.override_item("snowcone:cup_9", {
	groups = {snappy = 1}
})

minetest.register_craft({
	output = "snowcone:cup_1 3",
	recipe = {
		{"default:paper", "", "default:paper"},
		{"", "default:paper", ""}
	}
})

minetest.register_craft({
	output = "snowcone:raw",
	type = "shapeless",
	recipe = {"snowcone:cup_1", "default:snow"}
})
