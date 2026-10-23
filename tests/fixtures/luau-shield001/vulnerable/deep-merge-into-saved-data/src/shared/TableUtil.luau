local TableUtil = {}

-- Copies every field of `source` into `target` and returns `target`.
function TableUtil.assign(target, source)
	for key, value in source do
		target[key] = value
	end
	return target
end

return TableUtil
