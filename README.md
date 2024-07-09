# Alice: Toys of Madness

*Alice: Toys of Madness* is a GZDoom gameplay mod by Agent_Ash aka Jekyll Grim Payne that aims to reimagine the weapons and some gameplay systems from *American McGee's Alice* and (to a lesser degree) *Alice: Madness Returns* in GZDoom.

## Contents and requirements

**GZDoom 4.12.2** required

**Maps**: none (so far)

**Custom player class**: yes (required for full features; compatibility with other mods that utilize a custom player class is not guaranteed)

**Custom weapons, ammo, items**: yes

**Custom sounds**: yes

## Features

Play as Alice and lay waste to the demons! Features unique weapons, some unique items, entirely custom sprites, and some familiar 3D models and sounds.

### Player features

* 3D model for the player with different world-models for weapons and multiple animations

* Double jump

* Quick kick

* Anti-slip system when landing after a jump if the player is not pressing movement buttons (or pressing them in the opposite direction of the original jump).

### Weapons

* Vorpal Knife: Slice and dice, go snicker-snack! Throw the knife to stick it into enemies, then recall it at a press of a button.

* Hobby Horse: Crush your opponents with mighty blows, or perform a plunging attack with secondary fire. Note, the plunge, the higher the damage!

* Playing Cards: Sharp projectiles with mild homing capabilities. Secondary fire launches a volley of them with delayed homing. Perfect for medium and long range.

* Jacks: Throw these piercing gravity-affected projectiles with wild abandon, or throw a bunch of seeking jacks that will mercilessly bounce toward enemies for a time but will lock you out of throwing more until they return to you.

* Pepper Grinder: This is your pepper-flavored chaingun. Secondary fire turns the handle the other way, turning it into a makeshift shotgun!

* Teapot Cannon: Launch blobs of super-hot tea that explode and poison enemies they hit. Don't be afraid of overheating—you can let out the accumulated steam with secondary fire (it also pushes enemies away!)

* Ice Wand: The stream of freezing cold passes through enemies, slowing them down and eventually turning them into ice crystals. Secondary attack creates a temporary ice wall that shields you from attacks. Hint: once the ice wall starts to melt, hit it with primary attack to restore its integrity!

* Jabberwock's Eye Staff: The eye needs a bit of time to charge up, but then lets out a deadly and perfectly precise beam, and once you stop attacking, it finishes its focused destruction with a powerful magic missile. Secondary attack has a longer charge time, but it'll rain destruction over the selected area.

* Bluderbuss: Tsss... BOOM! That's all you need to now. The neat thing is, it can't damage you!

* Quick kick: At any time Alice can perform this elegant move to deal damage and push threats away.

### Unique powerups

* The Cake (replaces Invulnerability Sphere): It makes you grow, turning kicks into stomps, and enemy attacks into harmless tickling.

* Rage Box (replaces Berserk): Regeneration, reduced damage, and, most importantly RAGE! You will be locked to using your knife, but it will deal devastating damage.

* Looking-Glass Mirror (replaces Invisibility aka Blursphere): A *true* invisibility. Enemies won't know where you are—until you make some noise by attacking, that is, but even that alert will be only temporary.

## How to play

### How to play the latest stable release

Released versions should be the most stable and bug-free ones. Some releases are development versions which don't have all the planned features implemented yet.

1. Navigate to the "Releases" tab on the right, or follow this URL: https://github.com/jekyllgrim/Alice-Toys-of-Madness/releases/
2. Download the attached PK3 file. Run it as you'd run any .wad or .pk3. For example, in the command line it should look as follows:

```
gzdoom.exe -file AliceToysOfMadness###.pk3
```

(`###` in the example above stand for the version number, e.g. 130 for version 1.3.0)

### How to play the freshest dev build

It's possible to play the version that is currently in the repository but hasn't been made into a separate release yet:

1. Click [here](https://github.com/jekyllgrim/Alice-Toys-of-Madness/archive/refs/heads/main.zip) (or click the green "**Code**" button at the top right of this page and choose "**Download ZIP**"). This will download a file called `Alice-toys-of-madness-master.zip`.

2. Do not unpack the downloaded archive!

3. (Optional) Rename the downloaded **.zip** to **.pk3** to remember that you don't need to unpack it.

4. Run the archive as you would run any mod; from command line or a bat file in the GZDoom directory:
   
   ```
   gzdoom.exe -file Alice-toys-of-madness-master.zip
   ```
   
    Or, if you renamed it: 
   
   ```
   gzdoom.exe -file Alice-toys-of-madness-master.pk3
   ```

5. If you're getting errors, try running it with the latest [development build of GZDoom](https://devbuilds.drdteam.org/gzdoom/). Github builds may contain features that haven't made it into a stable GZDoom release yet.

6. Enjoy!

# Copyright information and permissions

*Alice: Toys of Madness* gameplay modification for GZDoom engine ("Alice: Toys of Madness") by Agent_Ash also known as Jekyll Grim Payne ("the Author") is based on the *American McGee's Alice* game by Rogue Entertainment and *Alice: Madness Returns* game by Spicy Horse; the intellectual property rights for those games belong to Electronic Arts. Alice: Toys of Madness consists of several components that are subject to different licenses and permissions.

### Short summary of the permissions (not equivalent to the full text):

* Most of the graphics in Alice: Toys of Madness (specifically, weapon sprites, item sprites and HUD graphics) are owned by the Author and may NOT be used, copied or edited by anyone for any purpose without first obtaining an explicit permission from the Author.
* The code used in Alice: Toys of Madness is licensed under General Public License version 3 (GPLv3) and can be used by anyone for any purpose, as long as the author of derivative projects complies with GPLv3, the original author or authors are credited, and the relevant license and copyright information is kept intact (i.e. all files containing license information shall be copied to derivate works).
* Most of the sounds used in Alice: Toys of Madness are owned by Electronic Arts and are used under Fair Use.

## The Artwork

The visual assets used in Alice: Toys of Madness, such as sprites, UI icons and other images, as well 3D models and their textures ("the Artwork") are split into several categories. The Artwork categories, as well as the corresponding permissions and artwork locations are listed below:

i.   Original artwork created by the Author (usually inspired by works of Rogue Entertainment and/or Spicy Horse)  
     **Permissions**: these assets may NOT be used, copied or edited by anyone for any purpose without first obtaining an explicit permission from the Author (with the exception of modifications made for personal use that will not be released publicly).  
     **Locations**: 

```
patches/Blunderbuss
patches/Cards
patches/Eyestaff
patches/HHorse
patches/Icewand
patches/Jacks
patches/Knife
patches/Legs
patches/PepperGrinder
patches/Teapot
patches/Items
```

ii.  Graphis and 3D models, originally created by Rogue Entertainment and/or Spicy Horse, modified in various ways, including but not limited to rescaling, color correction and partial redrawing  
     **Permissions**: these assets are used under Fair Use. The Author does not own this artwork or any licenses to it. This artwork may be removed from Alice: Toys of Madness, should copyright holders request it. You may use this artwork, as long as your use still falls under Fair Use.  
     **Locations**: most of the files under the /models/ folder of the project fall under this.

iii. Open-source assets  
     **Permissions**: can be used by anyone for any purpose.  
     **Locations**:

```
sprites/ (root folder)
sprites/SFX/
sprites/debris/
```

## The Code

The codebase of Alice: Toys of Madness includes original code produced by the Author, as well as several libraries, each under their own license.

**Summary of the permissions (not equivalent to the full license text):** 

* Alice: Toys of Madness codebase can be used freely by anyone for any purpose, provided the attached licene information is kept intact and the original authors are credited in all derivative works. 

* Some of the code in Alice: Toys of Madness is licensed under GPLv3. All code that is borrowed or based on that code also has to be licensed under GPLv3.

The code libraries, their license types and their locations are as follows:

1. Original code by the Author (with the occasional help of the members of the ZDoom community)  
    **License**: GPLv3  
    **Location**: `ZAlice/` (not including any subfolders)
2. *GZBeamz* library by Lewisk3  
    **License**: MIT  
    **Location**: `ZAlice/GZBeamz/`
3. *StatusBarScreen* library by Lewisk3  
    **License**: MIT  
    **Location**: `ZAlice/StatusBarScreen/`
4. *Gutamatics* library by Gutawer
    **License**: MIT
    **Location**: `ZAlice/ToM_Gutamatics/`

Refer to the aforementioned code locations for license information on each code component.

## The Audio

All sounds used in Alice: Toys of Madness are owned by Rogue Entertainment, and/or Spicy Horse, and/or Electronic Arts, and are used under Fair Use. The Author does not own any of the sounds or any licenses to them.

# Credits

Rogue Entertainment, Spicy Horse, American McGee: American McGee's Alice, Alice: Madness Returns, some of the graphics, 3D models, sounds, and the concept

Agent_Ash aka Jekyll Grim Payne: idea, code, graphics for items, weapons and the HUD

Cherno: huge help with American McGee's Alice asset ripping

Gutawer, themistercat, Ashley and others: shaders and ZScript help

Lewisk3: coding help, StatusBarScreen, 3D projectile firing function, math help
