{ 
	sub("fmsgeni","", host)

	ip = $1

	user = $3
	sub("SabaSite{sep}en_US{sep}","", user)

	date = substr($4,2,11)
	time = substr($4,14)
	hour = substr($4,14,2)
	
	method = substr($6,2)

	split($7,a,"?")
	url = a[1]
	if (a[2] == "")
		QueryString = "-"
	else
		QueryString = a[2]
		
	protocol = substr($8,6,3)
	response = $9
	
	if ($10 == "-")
		bytes = 0
	else
		bytes = $10
	
	print host "\t" ip "\t" user "\t" date " " time "\t" hour "\t" method "\t" url "\t" QueryString "\t" protocol "\t" response "\t" bytes
}