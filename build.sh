#!/bin/ash


for item in ./*.tl; do
	if [[ "$item" != ./*.d.tl ]]; then
		items="$items $item"
	fi
done

echo "Generating $items"
tl gen -c $items || exit 1
