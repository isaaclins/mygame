local StickerValidate = {}

function StickerValidate.validateSticker(sticker)
	if type(sticker) ~= "table" then
		return false, "Sticker must be a table"
	end
	if not sticker.id or sticker.id == "" then
		return false, "Missing sticker id"
	end
	if not sticker.name or sticker.name == "" then
		return false, "Missing sticker name"
	end
	if not sticker.description then
		return false, "Missing sticker description"
	end
	if not sticker.stack_limit or sticker.stack_limit < 1 then
		return false, "Invalid stack_limit"
	end
	if type(sticker.stackable) ~= "boolean" then
		return false, "stackable must be boolean"
	end
	if not sticker.rarity then
		return false, "Missing rarity"
	end
	if not sticker.svg_path or sticker.svg_path == "" then
		return false, "Missing svg_path"
	end
	if type(sticker.effect_hooks) ~= "table" then
		return false, "effect_hooks must be a table"
	end
	return true, nil
end

function StickerValidate.validateCatalog(catalog)
	local ids = {}
	for _, sticker in ipairs(catalog or {}) do
		local ok, err = StickerValidate.validateSticker(sticker)
		if not ok then
			return false, err
		end
		if ids[sticker.id] then
			return false, "Duplicate sticker id: " .. sticker.id
		end
		ids[sticker.id] = true
	end
	return true, nil
end

return StickerValidate
