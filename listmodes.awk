BEGIN{x=0}
{
if ($1 ~ "^"output)
	x++
else {
	if ($1 ~ /(^[[:digit:]]+)/ && x) {
		if ($0 ~ /\+/)
			printf "%s +\n", $1
		else
			print $1
	}
	else
		x=0
}
}
