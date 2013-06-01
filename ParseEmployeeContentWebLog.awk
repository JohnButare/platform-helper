{ 
	if (substr($1,1,1) != "#")
	{
		date = $1
		time = $2
		hour = substr($2,1,2)
		
		host=$4
		method=$6
		url=$7
		QueryString=$8

		if (a == "-")
		{
			split($10,a,"\\")
			domain=a[1]
			user=a[2]
		}
		else
		{
			domain="-"
			user = "-"
		}

		ip = $11
		response=$16
		bytes=$20
		TimeTaken=$21
		
		print host "\t" ip "\t" domain "\t" user "\t" date " " time "\t" hour "\t" method "\t" url "\t" QueryString "\t" response "\t" bytes "\t" TimeTaken
	}
}