
local S = minetest.get_translator("apartment")
local gui = flow.widgets
local p = {}

-- Get the renter's last login.
local function get_last_login(player_name)
	if not player_name or player_name == "" then
		return S("Never")
	end

	local auth_handler = minetest.get_auth_handler()
	if not auth_handler or not auth_handler.get_auth then
		return S("Unknown")
	end

	local auth = auth_handler.get_auth(player_name)

	if not auth or not auth.last_login or auth.last_login <= 0 then
		return S("Never")
	end

	return os.date("%Y-%m-%d %H:%M:%S", auth.last_login)
end

-- Identify chest nodes.
local function is_chest(node_name)
	local registered = minetest.registered_nodes[node_name]

	if not registered then
		return false
	end

	return minetest.get_item_group(node_name, "chest") > 0
		or node_name:lower():find("chest", 1, true) ~= nil
end

-- Count individual items in all chests inside an apartment.
local function count_apartment_chest_items(pos, meta)
	local node = minetest.get_node(pos)

	local size_up    = meta:get_int("size_up")
	local size_down  = meta:get_int("size_down")
	local size_right = meta:get_int("size_right")
	local size_left  = meta:get_int("size_left")
	local size_front = meta:get_int("size_front")
	local size_back  = meta:get_int("size_back")

	local x1 = pos.x
	local x2 = pos.x
	local z1 = pos.z
	local z2 = pos.z

	-- Use the same boundary calculations as apartment.rent().
	if node.param2 == 0 then
		-- Z gets larger
		x1 = x1 - size_left
		x2 = x2 + size_right
		z1 = z1 - size_front
		z2 = z2 + size_back

	elseif node.param2 == 1 then
		-- X gets larger
		z1 = z1 - size_right
		z2 = z2 + size_left
		x1 = x1 - size_front
		x2 = x2 + size_back

	elseif node.param2 == 2 then
		-- Z gets smaller
		x1 = x1 - size_right
		x2 = x2 + size_left
		z1 = z1 - size_back
		z2 = z2 + size_front

	elseif node.param2 == 3 then
		-- X gets smaller
		z1 = z1 - size_left
		z2 = z2 + size_right
		x1 = x1 - size_back
		x2 = x2 + size_front
	end

	local y1 = pos.y - size_down
	local y2 = pos.y + size_up

	local total_items = 0

	for x = x1, x2 do
		for y = y1, y2 do
			for z = z1, z2 do
				local chest_pos = {x = x, y = y, z = z}
				local chest_node = minetest.get_node_or_nil(chest_pos)

				if chest_node and is_chest(chest_node.name) then
					local inv = minetest.get_meta(chest_pos):get_inventory()
					local lists = inv:get_lists()

					if lists then
						for _, list in pairs(lists) do
							for _, stack in ipairs(list) do
								total_items = total_items + stack:get_count()
							end
						end
					end
				end
			end
		end
	end

	return total_items
end


p.configure_gui = flow.make_gui(function(player, ctx)
	local name = player:get_player_name()
	local pos = ctx.pos
	-- Error and privilege handling: These are unlikely to be reached, but anyway check them
	if not apartment.working then return gui.Label { label = "MOD_ERR" } end
	if not pos then return gui.Label { label = "NO_POS" } end
	local meta = ctx.meta or minetest.get_meta(pos)
	if meta:get_string('original_owner') ~= name then return gui.Label { label = "NOT_OWNER" } end

	local defaults = {}
	if ctx.defaults then
		for x, y in pairs(ctx.defaults) do
			defaults[x] = tostring(y)
		end
		ctx.defaults = nil
	end

	return gui.VBox { w = 10,
		gui.Label { label = S("Apartment Configuration") },
		gui.Box { w = 1, h = 0.05, color = "grey" },
		gui.HBox {
			gui.Label { label = S("Category"), w = 2 },
			gui.Field { name = "category", expand = true, default = defaults.category },
			gui.Tooltip {
				tooltip_text = S("In one category, every player can only rent one apartment."),
				gui_element_name = "category",
			}
		},
		gui.HBox {
			gui.Label { label = S("Name or ID"), w = 2 },
			gui.Field { name = "descr", expand = true, default = defaults.descr },
			gui.Tooltip {
				tooltip_text = S("This is the unique ID of this apartment in this category."),
				gui_element_name = "descr",
			}
		},
		gui.Box { w = 1, h = 0.05, color = "grey" },
		gui.Label { label = S("The apartment shall extend this many blocks from this panel:") },
		gui.HBox {
			gui.VBox {
				gui.Field {
					name = "size_back", label = S("Back"),
					w = 1, expand = true, align_h = "center",
					default = defaults.size_back,
				},
				gui.HBox {
					gui.Field {
						name = "size_left",
						label = S("Left"),
						w = 1, expand = true,
						default = defaults.size_left,
					},
					gui.Image {
						w = 1, h = 1, texture_name = "apartment_controls_vacant.png",
						expand = true,
					},
					gui.Field {
						name = "size_right",
						label = S("Right"),
						w = 1, expand = true,
						default = defaults.size_right,
					},
				},
				gui.Field {
					name = "size_front", label = S("Front"),
					w = 1, expand = true, align_h = "center",
					default = defaults.size_front
				},
			},
			gui.VBox { w = 4, expand = true, align_h = "right",
				gui.HBox {
					gui.Field {
						name = "size_up",
						label = S("Up"),
						expand = true, w = 1,
						default = defaults.size_up,
					},
					gui.Field {
						name = "size_down",
						label = S("Down"),
						expand = true, w = 1,
						default = defaults.size_down,
					},
				},
				gui.Spacer {},
				gui.ButtonExit {
					name = "abort",
					label = S("Abort"),
				},
				gui.ButtonExit {
					name = "store",
					label = S("Store and Offer"),
					on_event = function(player, ctx)
						local name = player:get_player_name()
						local pos = ctx.pos
						-- Error and privilege handling: These are unlikely to be reached, but anyway check them
						if not apartment.working then return false end
						if not pos then return false end
						local meta = ctx.meta or minetest.get_meta(pos)
						if meta:get_string('original_owner') ~= name then return gui.Label { label = "NOT_OWNER" } end
						local fields     = ctx.form
						local size_left  = tonumber(fields.size_left or -1) or -1
						local size_right = tonumber(fields.size_right or -1) or -1
						local size_up    = tonumber(fields.size_up or -1) or -1
						local size_down  = tonumber(fields.size_down or -1) or -1
						local size_front = tonumber(fields.size_front or -1) or -1
						local size_back  = tonumber(fields.size_back or -1) or -1
						local category   = tostring(fields.category) or ""
						local descr      = tostring(fields.descr) or ""

						if math.min(size_left, size_right, size_up, size_down, size_front, size_back) < 0
						or not category or not descr then
							minetest.chat_send_player(name, S("Error: Not all fields have been filled."))
							return
						end

						if math.max(size_left, size_right, size_up, size_down, size_front, size_back) > 10 then
							minetest.chat_send_player(name, S("Error: The area is too large."))
							return
						end

						if apartment.apartments[category] and apartment.apartments[category][descr] then
							minetest.chat_send_player(name,
								S("Error: The apartment @1@@@2 already exists. " ..
								  "Please choose a different name or category.",
									descr, category))
							return
						end

						meta:set_int('size_up', size_up)
						meta:set_int('size_down', size_down)
						meta:set_int('size_right', size_right)
						meta:set_int('size_left', size_left)
						meta:set_int('size_front', size_front)
						meta:set_int('size_back', size_back)

						meta:set_string('descr', fields.descr)
						meta:set_string('category', fields.category)

						local status, msg = apartment.rent(pos, name, nil, player)
						if status then
							minetest.chat_send_player(name, S("Apartment @1@@@2 is ready for rental.", descr, category))
						else
							minetest.chat_send_player(name,
								S("Failed to create apartment @1@@@2. (@3)", descr, category, msg))
						end
					end
				},
				gui.Style {
					selectors = { "abort" },
					props = { textcolor = "#FF0000" }
				}
			}
		}
	}
end)

p.panel_control = flow.make_gui(function(player, ctx)
	local name = player:get_player_name()
	local pos = ctx.pos
	-- Error and privilege handling: These are unlikely to be reached, but anyway check them
	if not apartment.working then return gui.Label { label = "MOD_ERR" } end
	if not pos then return gui.Label { label = "NO_POS" } end

	local meta = ctx.meta or minetest.get_meta(pos)

	local original_owner = meta:get_string('original_owner')
	local owner = meta:get_string('owner')
	local owner_disp = ((owner == original_owner or owner == "") and S("- vacant -") or owner)
	local descr = meta:get_string('descr')
	local category = meta:get_string('category')

	-- Renter information.
	local renter_active = owner ~= "" and owner ~= original_owner

	local last_login = "-"
	local chest_items = "-"
	local can_view_chest_items = minetest.check_player_privs(name, {
		apartment_unrent = true
	})

	if renter_active then
		last_login = get_last_login(owner)
		if can_view_chest_items then
			chest_items = tostring(count_apartment_chest_items(pos, meta))
		end
	end

	local btn = gui.Label { label = S("This apartment \nhave been rented.") }
	if not (apartment.apartments[category] and apartment.apartments[category][descr]) then
		btn = gui.Label { label = S("This apartment \nwas glitched.") }
	elseif name == owner and owner ~= original_owner then
		btn = gui.Button {
			label = S("Unrent"),
			on_event = function(player, ctx)
				local name = player:get_player_name()
				local pos = ctx.pos
				-- Error and privilege handling: These are unlikely to be reached, but anyway check them
				if not apartment.working then return end
				if not pos then return end

				local meta = ctx.meta or minetest.get_meta(pos)
				local original_owner = meta:get_string('original_owner')
				local descr = meta:get_string('descr')
				local category = meta:get_string('category')
				local status, msg = apartment.rent(pos, original_owner, nil, player)
				if status then
					minetest.chat_send_player(name,
						S("You have ended your rent of apartment @1@@@2. It is free for others to rent again.",
							descr, category))
				else
					minetest.chat_send_player(name,
						S('Something went wrong when giving back the apartment @1@@@2. (@3)',
							descr, category, msg))
				end
				return true
			end
		}
	elseif owner == original_owner then
		if name == original_owner then
			btn = gui.Label { label = S("Dig the panel \nto remove this apartment.") }
		else
			btn = gui.Button {
				label = S("Rent"),
				on_event = function(player, ctx)
					local name = player:get_player_name()
					local pos = ctx.pos
					-- Error and privilege handling: These are unlikely to be reached, but anyway check them
					if not apartment.working then return end
					if not pos then return end

					local meta = ctx.meta or minetest.get_meta(pos)
					local descr = meta:get_string('descr')
					local category = meta:get_string('category')

					if not (apartment.apartments[category] and apartment.apartments[category][descr]) then
						minetest.chat_send_player(name,
							S("This apartment (@1@@@2) is not registered. " ..
							  "Please unrent it and ask the original builder to re-configure this panel.",
								descr, category))
						return true
					end

					for k, v in pairs(apartment.apartments[category]) do
						if v and v.owner == name then
							minetest.chat_send_player(name,
								S("Sorry, you can only rent one apartment per category at a time. " ..
								  "You have already rented apartment @1@@@2.",
									descr, category))
							return false
						end
					end

					local status, msg = apartment.rent(pos, name, nil, player)
					if status then
						minetest.chat_send_player(name,
							S("You have rented apartment @1@@@2. Enjoy your stay!", descr, category))
					else
						minetest.chat_send_player(name,
							S('Something went wrong when renting the apartment @1@@@2. (@3)',
								descr, category, msg))
					end
					return true
				end
			}
		end
	elseif name == original_owner or minetest.check_player_privs(name, { apartment_unrent = true }) then
		btn = gui.Button {
			label = S("Force Unrent"),
			on_event = function(player, ctx)
				local name = player:get_player_name()
				local pos = ctx.pos
				-- Error and privilege handling: These are unlikely to be reached, but anyway check them
				if not apartment.working then return end
				if not pos then return end

				local meta = ctx.meta or minetest.get_meta(pos)
				local original_owner = meta:get_string('original_owner')
				local descr = meta:get_string('descr')
				local category = meta:get_string('category')
				local owner = meta:get_string('owner')

				if not (name == original_owner or minetest.check_player_privs(name, { apartment_unrent = true })) then return end

				local status, msg = apartment.rent(pos, original_owner, nil, player)
				if status then
					minetest.chat_send_player(name,
						S("Player @1 has been thrown out of apartment @2@@@3. It can now be rented by another player.",
							owner, descr, category))
				else
					minetest.chat_send_player(name,
						S('Something went wrong when throwing @1 out of the apartment @2@@@3. (@4)',
							owner, descr, category, msg))
				end
				return true
			end
		}
	end

	local size_up    = meta:get_int('size_up');
	local size_down  = meta:get_int('size_down');
	local size_right = meta:get_int('size_right');
	local size_left  = meta:get_int('size_left');
	local size_front = meta:get_int('size_front');
	local size_back  = meta:get_int('size_back');

	return gui.VBox { w = 10,
		gui.HBox {
			gui.Label { label = S("Apartment @1@@@2", descr, category) },
			gui.ButtonExit {
				label = "x", w = 0.5, h = 0.5,
				expand = true, align_h = "right",
			}
		},
		gui.Box { w = 1, h = 0.05, color = "grey" },
		gui.HBox {
			gui.Label { label = S("Owner: @1", original_owner), w = 1, expand = true },
			gui.Label { label = S("Now rented by: @1", owner_disp), w = 1, expand = true },
		},

		-- Renter information.
		gui.Box { w = 1, h = 0.05, color = "grey" },
		gui.Label { label = S("Renter Information") },
		gui.HBox {
			gui.Label {
				label = S("Last login: @1", last_login),
				w = 1, expand = true
			},
			can_view_chest_items and gui.Label {
				label = S("Items in chests: @1", chest_items),
				w = 1, expand = true
			} or gui.Label {
				label = "",
				w = 1, expand = true
			},
		},

		gui.Box { w = 1, h = 0.05, color = "grey" },
		gui.Label { label = S("The apartment extends this many blocks from this panel:") },
		gui.HBox {
			gui.VBox {
				gui.Label {
					label = S("Back") .. "\n" .. size_back,
					w = 1, expand = true, align_h = "center"
				},
				gui.HBox {
					gui.Label {
						label = S("Left") .. "\n" .. size_left,
						w = 1, expand = true,
					},
					gui.Image {
						w = 1, h = 1, texture_name = "apartment_controls_vacant.png",
						expand = true,
					},
					gui.Label {
						label = S("Right") .. "\n" .. size_right,
						w = 1, expand = true,
					},
				},
				gui.Label {
					label = S("Front") .. "\n" .. size_front,
					w = 1, expand = true, align_h = "center"
				},
			},
			gui.VBox { w = 4, expand = true, align_h = "right",
				gui.HBox {
					gui.Label {
						label = S("Up") .. "\n" .. size_up,
						expand = true, w = 1,
					},
					gui.Label {
						label = S("Down") .. "\n" .. size_down,
						expand = true, w = 1,
					},
				},
				gui.Spacer{},
				btn,
			}
		}
	}
end)

return p
