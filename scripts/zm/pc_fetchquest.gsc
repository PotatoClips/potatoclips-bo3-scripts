#using scripts\shared\array_shared;//needs to be at the top of whereever you put this script
#using scripts\shared\flag_shared;//needs to be at the top of whereever you put this script
#using scripts\zm\_zm_score;
/*
#####################
fetch quest script by PotatoClips and Kaizokuroof
modified from shootable ee by: M.A.K.E C E N T S
#####################
ADD TO:

//above main in usermap gsc
#using scripts\zm\pc_fetchquest;

//in main in usermap gsc, add one for each quest
pc_fq::init("[questname]", [reward]);

//in zone list
scriptparsetree,scripts/zm/pc_fetchquest.gsc

HOW TO:
label a trigger_use targetname kvp as "fetchquest_1_start", "fetchquest_1_find", "fetchquest_1_return"
add a script_model and link to the trigger by selecting the trigger and then the script model, and then press 'w'
do this for each component of the quest and it should all work

"start" refers to the trigger targetname that activates the fetch quest
"find" refers to the trigger targetname of the item(s) that need to be found
"return" refers to the trigger targetname that completes the fetch quest and deletes the start trigger
"fetchquest_1_door" is used to pick a door that will open when the quest has been completed

###############################################################################
*/
#namespace pc_fq;

function init(kvp, reward){
	self endon( "death" ); 
    level endon( "disconnect" );
	level endon("end_game");															//end script if game ends
	level.pc_fetchquest = [];
	//quests = get all entities that include basekvp of "fetchquest_" and "_start"
	//for each quest, thread fetchquest function with basekvp + questindex, entity added scripts (cost)
	level thread FetchQuest(kvp, reward);
	//level thread FetchQuest("fetchquest_2", 1000);
	//thread FetchQuest("fetchquest_3", 2000);											//repeat this pattern to add more fetch quests, number is point reward
}

/*
#####################
	S E T U P
#####################
*/

function FetchQuest(kvp, reward){
	wait(2);
	self endon( "death" ); 
    self endon( "disconnect" );
	level endon("end_game");															//end script if game ends
	questDoors = GetEntArray(kvp + "_door","targetname");								//get the door(s)
	questStart = GetEntArray(kvp + "_start","targetname");								//get the start trigger
	questFindables = GetEntArray(kvp + "_find","targetname");							//get the findables
	questReturn = GetEntArray(kvp + "_return","targetname");							//get the return trigger
	if(questDoors.size<=0){
		thread Report("Door for " + kvp + " is not defined.");							//added for troubleshooting
	}
	else	thread HandlePoints(kvp, reward);

	if(questStart.size<=-0){
		thread Report("I didn't find the start trigger in" + kvp);
		return;
	}
	if(questFindables.size<=-0){
		thread Report("I didn't find any findables in" + kvp);
		return;
	}
	if(questReturn.size<=-0){
		thread Report("I didn't find the return trigger in" + kvp);
		return;
	}
	level.pc_fetchquest[kvp + "_find"] = questFindables.size;							//set this findable size to the number of findables
	array::thread_all(questStart,&HandleStart, kvp);									//thread a handleStart function for each quest starter, pass the kvp var to each
	array::thread_all(questFindables,&HandleFindables, kvp);
	array::thread_all(questReturn,&HandleReturn, kvp);

	array::thread_all(questDoors, &HandleDoor, kvp);									//thread a handledoor function for each quest door, pass the kvp var to each

}

function HandleStart(kvp){
	self SetHintString("Press and hold ^3[{+activate}]^7 to start task.");				//display message when looking closely at the quest giver
	self waittill("trigger");															//wait until it is triggered
	if(isdefined(self.target))	startModels = GetEntArray(self.target,"targetname");	//get an array of the triggers targets, incase you used more than one model
	else	thread Report("You never set the start script_models");						//print message
	foreach(startModel in startModels){
		startModel Delete();															//delete every model linked to the start trigger
	}
	level notify(kvp + "_start");														//let the script know the quest has started
	thread Report("A new quest has started");											//print quest update
	self Delete();																		//delete the trigger
}

function HandleFindables(kvp){
	level waittill(kvp + "_start");														//wait until the script is told that the quest has started
	self SetHintString("Press and hold ^3[{+activate}]^7 to search.");					//display message when looking closely at the item
	self waittill("trigger");															//wait until it is triggered
	if(isdefined(self.target))	findModels = GetEntArray(self.target,"targetname");		//get an array of the triggers targets, incase you used more than one model
	else	thread Report("You never set the find script_models");						//added for troubleshooting
	level.pc_fetchquest[self.targetname]--;												//remove one from the total
	foreach(findModel in findModels){
		findModel Delete();																//delete every item script_model
	}
	if(level.pc_fetchquest[self.targetname]<=0){										//check if all have been found
		level notify(kvp + "_find");													//let the script know that there are no more items to find
		thread Report("You have found all items.");										//print quest update
	}
	self Delete();																		//delete the trigger
}

function HandleReturn(kvp){
	level waittill(kvp + "_find");														//wait until the script is told there are no more items to find
	self SetHintString("Press and hold ^3[{+activate}]^7 to claim reward.");			//display message when looking closely at the quest return trigger
	self waittill("trigger");															//wait until it is triggered
	if(isdefined(self.target))	returnModels = GetEntArray(self.target,"targetname");	//get an array of the triggers targets, incase you used more than one model
	else	thread Report("You never set the return script_models");					//added for troubleshooting
	foreach(returnModel in returnModels){
		returnModel Delete();															//delete every model linked to the return trigger
	}
	level notify(kvp + "_return");														//let the script know that the quest items have been turned in
	thread Report("You have been given a reward.");										//print quest update
	PlaySoundAtPosition("purchase",self.origin);
	self Delete();																		//delete the triggers
}

/*
#####################
	R E W A R D S
#####################
*/

/*-----------------POINTS-----------------*/
function HandlePoints(kvp, reward){
	level waittill(kvp + "_return");													//waits for the findables to be returned
	thread GivePoints(reward);															//call GivePoints function, send point value through
}
function GivePoints(reward){
	players = GetPlayers();																//make a list of all players
	foreach(player in players){
		player zm_score::add_to_player_score(reward);									//give points to every player in the list
	}
}

/*-----------------WEAPONS-----------------*/
//function HandleWeapons(reward){

//}

/*-----------------PERKS-----------------*/
//function HandlePerks(reward){

//}

/*-----------------DOORS-----------------*/
function HandleDoor(kvp){																//if using a model, this would be the clip, with the actual door as the target
	self DisconnectPaths();																//makes it so zombies don't try to walk through it
	if(isdefined(self.script_flag))		flag::init(self.script_flag);					//init the flag
	level waittill(kvp + "_return");													//waits for the findables to be returned
	if(isdefined(self.script_flag))		flag::set(self.script_flag);					//set the flag allowing for zombies to spawn in this zone
	self NotSolid();																	//makes it so you can walk through it before it starts to move
	self ConnectPaths();																//makes it so zombies can path through it now
	if(isdefined(self.target) && self.target!=""){
		doors = GetEntArray(self.target,"targetname");									//this is the doors if your using a model, target of the clip
		foreach(door in doors){
			level endon("end_game");													//end script if game ends
			door thread OpenDoor();														//open this door piece
		}
		self delete();																	//delete the clip
	}
	else	self thread OpenDoor();														//added another function to add more options of opening doors
}
function OpenDoor(){																	//default reward is door
	if(!isdefined(self.script_noteworthy) || self.script_noteworthy=="move"){
		move = (0,0,100);
		if(isdefined(self.script_vector)) move = self.script_vector;
		self MoveTo(self.origin + move,1);												//move door up 100 units
	}
	if(!isdefined(self.script_noteworthy) || self.script_noteworthy=="rotate"){
		//rotate = (0,0,120);
		//if(isdefined(self.script_vector)) rotate = self.script_vector;
		//self MoveTo(self.origin + rotate,1);
	}
}

/*-----------------REPORTS-----------------*/
function Report(text, moretext = ""){													//receive text variable, set default moretext to nothing
	level flag::wait_till( "initial_blackscreen_passed" );								//wait until blackscreen goes away
	IPrintLnBold(text);																	//print text in bold
	IPrintLn(text);																		//move down a line
	wait(.5);																			//wait half a second
	if(moretext!="") IPrintLnBold(moretext);											//if there is more text, print it now
}

/*
#####################
	N O T E S
#####################
*/

/*
Future Plans:
- keep track of all quests in the map and give reward for completing all of them
- add door rotation option
- delete the quest start entity once the quest is turned in
- allow items to be picked up before quest is started but dont allow claim of reward until it is started and all items are found
- add sounds and effects
- lua quest menu
- add an alt return trigger and reward if defined
*/
