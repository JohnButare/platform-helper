{ 
	sub("fm1sesweb","", host)

	if (substr($1,1,1) != "#")
	{
		date = $1
		time = $2
		hour = substr($2,1,2)
		
		method=$3
		url=$4
		QueryString=$5

		split($6,a,"\\")
		domain=a[1]
		user=a[2]

		ip = $7 
		
		#browser=$8
		#cookies=$9
		#referrer=$10
		
		response=$11
		bytes=$12
		TimeTaken=$13	
		
		print host "\t" ip "\t" domain "\t" user "\t" date " " time "\t" hour "\t" method "\t" url "\t" QueryString "\t" response "\t" bytes "\t" TimeTaken
	}
}