BEGIN{x=0}
{
if ($1 ~ "^"output)
	x++
else {
	if ($1 ~ /(^[[:digit:]]+)/ && x)
		print $1
	else
		x=0
}
}
