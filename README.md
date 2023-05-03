# Enigma-Cold-War-V1-Public
Enigma's Cold War V1 Code base for public use for the DCS Community


***Introduction***
On launch date of Enigma's Dynamic Cold War PVP/PVE Server, we said that if the server failed then we could still be succesful.
Our thinking was that if other servers saw what concepts we were introducing into DCS and adapted them then we could help push
things into a better direction.


To our surprise, the server was a success and we have grown quite a bit. Along the way, we have received help by many people.
Some were community members that volunteered their time to help us, regardless if they were on the staff or not.


For that, we want to give back the community and we are making our original codebase public. We hope that by making this available
we will help inspire people to help push DCS from what it is to an actual game that is anchored around dynamic scenarios.


I cannot promise to answer every single code question, most of the developers that were on the project have left DCS and I am not a
developer. Additionally, I am very time crunched but I will do my best to answer some questions. We were hoping to make this available 
much earlier but we got very busy with our V2 launch. So I apologize if the documentation is a little light. 
If you need to get in touch please ping me on Discord or drop a YouTube comment:
https://discord.gg/3ZMttnKmkh
https://www.youtube.com/c/@enigma89

Please note that this codebase traded a lot of hands, ALL of the code was made by the following people:
Whosvee (original developer and created the basic frontline + depot system)
Matroshka (V1 lead developer)
Wizard (created slotblocker and bubble protection)
Yink (Current Enigma lead developer, in V1 he created recon and the helicopter mechanics)

***Notes***

This breaks down how the code works:

Hooks/slotblocker - This is the slotblocker, you can configure the rules as you wish

Scripts/EventsSyria.lua - This is the bomber and boat events on Syria. There is a debugger mode for this.

Scripts/airbases.lua - This is a protection bubble to make sure at least one airfield is always playable

Scripts/base-spawncheck-off.lua - I forgot what this is (Sorry)

Scripts/base.lua - This is the most important file and is the actual campaign system.

Scripts/Bombers.lua - This is the same as EventsSyria.lua but for Caucauses only

Scripts/Collection.lua - This is a file that determines assets/groups that exist on the map

Scripts/Collection_syria.lua - Same as above but for Syria

Scripts/Functions.lua - I forgot what this is (Sorry)

Scripts/hookLoader.lua - This is what loads the hooks

Scripts/loader.lua - This loads all of the scripts

Scripts/logger.lua - Self-explanatory

Scripts/punisher.lua - This is what we used to protect roadbases from attacks

Scripts/recon.lua - This is the recon system. Variables can be set for planes

Scripts/serverstatus.lua - I forgot what this is (Sorry)

Scripts/Variables.lua - This is what non-developers use to control the mission and set variables for things such as values in the campaign

Scripts/yink.lua - This is where attrition and helicopters mechanics exist


If you run into any issues, I would recommend making sure to update your Moose version you are using. 


**THANKS AND LIKE AND SUBSCRIBE YOU NERDS**
