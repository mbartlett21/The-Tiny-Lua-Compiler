#!/bin/ash


for item in ./*.tl; do
	case "$item" in
		*.d.tl) ;;
		*) items="$items $item" ;;
	esac
done

echo "Generating $items"
tl gen -c $items || exit 1
