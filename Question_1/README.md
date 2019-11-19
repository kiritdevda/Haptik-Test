# Question_1

Contains questions and answer to haptik test for question_1


### 1.a

Question :

```
Kill all processes/zombie processes of service called “gunicorn” in a single command
```

Answer :

```
ps -ef | grep 'gunicorn' | grep -v grep | awk '{print $2}' | xargs -r kill -9

The above command will list all process which has word gunicorn in it and will kill each one of them by passing each one to kill -9 thus also killing zombie processes 
```

### 1.b

Question :

```
MySQL shell command to show the unique IPs from where MySQL connections are being made to the Database. 
```

Answer :

```
select distinct host from information_schema.processlist WHERE ID=connection_id();

The above command list all the ip which have connected to the database and distinct only gives unique ip's
```

### 1.c

Question :

```
Bash command to get value of version number of 3 decimal points (first occurrence) from a file containing the JSON: 

 {  "name": "abc",
    "version": "1.0",
    "version": "1.0.57",
    "description": "Testing",
    "main": "src/server/index.js",
    "version": "1.1"  } 
```

Answer :

```
awk -F: '$1=="\"version\""{gsub(/"/, "", $2);printf "%0.2f\n", $2;exit;}' version.txt

there are three parts to command 
first part : for each line check whether we have "version" string in first column
first part/second scetion : for filtered line with version string remove " (quotation) from second column so that string to int conversion is easier for arthmetic operation

second part : print the second column data put to only two decimal places 

third part : exit, Since we have specified exit the first occurence where we find version is only processed 

```

### 1.d

Question :

```
Bash command to add these numbers from a file and find average upto 2 decimal points:  
0.0238063905753 
0.0308368914424
0.0230014918637
0.0274232220275 
0.0184563749986 

```

Answer :

```
awk '{ sum += $1 } END { printf "%0.2f\n", sum }' add.txt

command has two parts

Part 1 : Iterate each line and add the values 
part2  : print final result upto two decimal places

```
