local TableUtil = {}
-- Copies the fields of every source into target and returns target.
function TableUtil.assign(target, ...)
	for _, source in { ... } do
		for key, value in source do
			target[key] = value
		end
	end
	return target
end
return TableUtil
