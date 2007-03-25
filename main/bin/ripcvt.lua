#!/usr/local/bin/lua

--[[
                           NOTICE

This is - at best - alpha quality software. It has not been tested by
anyone but me, so don't expect much of it, and be careful to use it
against backed up data.
Success and failures reports are welcome.
]]

--[[
===============================================================================

Copyright (C) 2007 Eric Dujardin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

===============================================================================
]]

--[[
RipCvt is a tool to automate the conversion of ripped audio between various
formats. Currently it uses Flac, Ogg, Mp3-vbr and Mp3-vbr. 
If there's interest for others, LMKODIY (let me know or do it yourself)

The motivation for writing this in Lua instead of Bash, Perl or Python is 
first to use an exec-like API, thus being freed of quoting issues (characters
like !, ?, ' and " in songs titles are really annoying), and to learn Lua.

RipCvt has been tested exclusively with Lua-5.1 on Linux and should run on 
others UNIX variants. It would require some porting effort to run on Windows 
so as to accomodate Windows paths (again, LMKODIY).

RipCvt depends on the following programs: flac, oggenc, oggdec, lame, mpg321
It also depends on the "ex" Lua package (see 
  http://lua-users.org/files/wiki_insecure/users/MarkEdgar/exapi)

This is version 0.4.

Use is as:

ripcvt.lua [--target-format|-f format-list] [--target-dir|-d directory] [path]*

where each path has "flac" either as direct subdirectory or as a parent directory.
RipCvt will create "ogg", "mp3" and "cmp" directories as brothers of this
"flac" directory. It will inspect all subdirectories of the given path to
find *.flac files in final subdirs (that is, subdirs without subdirs), build
the corresponding subtrees under "ogg", "mp3" and "cmp", and convert the flac
files as expected into the "ogg", "mp3" and "cmp" subtrees.
]]

require ("ex")

doflac,doogg,domp3,docmp=0,0,0,0
targetdir=''

--  ########## COMMON FUNCTIONS #########

-- returns the position of char in str, or 0 if absent. 
function pos(str,char)
   local i
   for i=1,string.len(str),1 do
      if string.byte(str,i) == char then
	 return i
      end
   end
   return 0
end

-- returns with all components of dirname as items of list
function decompose(dirname,list)
   local p=pos(dirname,47) -- 47 is '/'
   if (p ~= 0) then
      table.insert(list,string.sub(dirname,1,p-1))
      return decompose(string.sub(dirname,p+1,string.len(dirname)),list)
   else
      table.insert(list,dirname)
      return 1
   end
end

-- ######### OUTPUT GENERATION ########

--[[ 
    compute destination flac, ogg, mp3 and cmp dirs from srcDir. 
    srcDir is an absolute path
    fmt is the source format, ie the format of the files in srcDir
    result is nil when format is not required
]]
function dirs(srcDir,fmt)
   local srcpos=string.find(srcDir,"/"..fmt)
   local flacdir,oggdir,mp3dir,cmpdir
   if (not srcpos) then
      -- srcDir not an absolute path !!
      return nil,nil,nil,nil
   end
   local top
   if (targetdir == '') then
      top=string.sub(srcDir,1,srcpos-1)
   else
      top=targetdir
   end
   local relpath=string.sub(srcDir,srcpos+2+#fmt)
   local dirl={}
   decompose(relpath,dirl)
   os.chdir(top)
   if ((fmt ~= "flac") and doflac) then
      os.mkdir("flac")
      if (os.chdir("flac")) then
	 for i,d in ipairs(dirl) do
	    os.mkdir(d)
	    os.chdir(d)
	 end
	 flacdir=os.currentdir()
      end
   end
   os.chdir(top)
   if ((fmt ~= "ogg") and doogg) then
      os.mkdir("ogg")
      if (os.chdir("ogg")) then
	 for i,d in ipairs(dirl) do
	    os.mkdir(d)
	    os.chdir(d)
	 end
	 oggdir=os.currentdir()
      end
   end
   os.chdir(top)
   if ((fmt ~= "mp3") and domp3) then
      os.mkdir("mp3")
      if (os.chdir("mp3")) then
	 for i,d in ipairs(dirl) do
	    os.mkdir(d)
	    os.chdir(d)
	 end
	 mp3dir=os.currentdir()
      end
   end
   os.chdir(top)
   if ((fmt ~= "cmp") and docmp) then
      os.mkdir("cmp")
      if (os.chdir("cmp")) then
	 for i,d in ipairs(dirl) do
	    os.mkdir(d)
	    os.chdir(d)
	 end
	 cmpdir=os.currentdir()
      end
   end
   os.chdir(top)
   return flacdir,oggdir,mp3dir,cmpdir
end

-- remove trailing suffix
function basename (name,suffix)
   local pos=string.find(name,suffix.."$")
   if (pos==nil) then
      return nil
   end
   return string.sub(name,1,pos-1)
end

-- convert audio files from one source dir 
-- target dir is nil for unneeded formats
function convert(srcdir,flacdir,oggdir,mp3dir,cmpdir)
   local current
   local title
   os.chdir(srcdir)
   for current in os.dir(".") do
      p1,p2,p3,p4=nil,nil,nil,nil
      title=basename(current.name,".flac")  
      if (current.type == "file") and (title ~= nil) then
	 print("converting "..title)
	 if (doogg) then
	    p1=os.spawn("/usr/bin/oggenc",{args={"--quiet","-o",oggdir.."/"..title..".ogg",current.name}})
	 end
	 if (domp3 or docmp) then
	    p2=os.spawn("/usr/bin/flac",{args={"--silent","-d","-f","-o","tempo.wav",current.name}})
	    p2:wait()
	    p2=nil
	    if (domp3) then
	       p3=os.spawn("/usr/bin/lame",{args={"--silent","--preset","standard","tempo.wav",mp3dir.."/"..title..".mp3"}})
	    end
	    if (docmp) then
	       p4=os.spawn("/usr/bin/lame",{args={"--silent","--preset","cbr","128","tempo.wav",cmpdir.."/"..title..".mp3"}})
	    end
	 end
      end 

      title=basename(current.name,".ogg")  
      if (current.type == "file") and (title ~= nil) then
	 print("converting "..title)
	 p1=os.spawn("/usr/bin/oggdec",{args={current.name,"-o","tempo.wav"}})
	 p1:wait()
	 if (doflac) then
	    p1=os.spawn("/usr/bin/flac",{args={"--best","-o",flacdir.."/"..title..".flac","tempo.wav"}})
	 end
	 if (domp3) then
	    p3=os.spawn("/usr/bin/lame",{args={"--silent","--preset","standard","tempo.wav",mp3dir.."/"..title..".mp3"}})
	 end
	 if (docmp) then
	    p4=os.spawn("/usr/bin/lame",{args={"--silent","--preset","cbr","128","tempo.wav",cmpdir.."/"..title..".mp3"}})
	 end
      end

      title=basename(current.name,".mp3")
      if (current.type == "file") and (title ~= nil) then
	 print("converting "..title)
	 if (doflac or doogg) then
	    p1=os.spawn("/usr/bin/mpg321",{args={"--wav","tempo.wav",current.name}})
	    p1:wait()
	 end

	 if (doflac) then
	    p1=os.spawn("/usr/bin/flac",{args={"--best","-o",flacdir.."/"..title..".flac","tempo.wav"}})
	 end
	 if (doogg) then
	    p2=os.spawn("/usr/bin/oggenc",{args={"--quiet","-o",oggdir.."/"..title..".ogg",current.name}})	    
	 end
	 if (domp3 and not string.match(srcdir, "/mp3")) then
	    p3=os.spawn("/usr/bin/lame",{args={"--silent","--preset","standard",current.name,mp3dir.."/"..title..".mp3"}})
	 end
	 if (docmp and not string.match(srcdir, "/cmp")) then
	    p4=os.spawn("/usr/bin/lame",{args={"--silent","--preset","cbr","128",current.name,cmpdir.."/"..title..".mp3"}})
	 end
      end

      if (p1) then
	 p1:wait()
      end
      if (p2) then
	 p1:wait()
      end
      if (p3) then
	 p3:wait()
      end
      if (p4) then
	 p4:wait()
      end

   end
   os.remove("tempo.wav")
end

-- ######### INPUT PARSING AND ANALYSIS ######### 

-- get all final subdirs of current dir, that is, subdirs 
-- without subdirs themselves. Put result in "dirs" arg.
function getAllSubDirs(dirl)
   print ("getAllSubDirs", os.currentdir())
   local final=1
   local orig=os.currentdir()
   for current in os.dir(".") do
      if (current.type == "directory") then
	 final=nil -- current is not a final directory
	 os.chdir(current.name) -- explore subdir
	 getAllSubDirs(dirl)
	 os.chdir(orig)  -- come back each time
      end
   end
   if (final) then
      table.insert(dirl,os.currentdir())
   end
end


-- compute a set of source dirs from one root
function getSrcDirs(a_root, flacDirs, oggDirs, mp3Dirs, cmpDirs)
   print ("getSrcDirs", a_root, os.currentdir() )
   local start=os.currentdir()
   os.chdir(a_root)
   local root=os.currentdir() -- absolute path

   local allDirs={}
   getAllSubDirs(allDirs)

   for i,d in ipairs(allDirs) do
      if (string.match(d,"/flac")) then
	 table.insert(flacDirs,d)
      end
      if (string.match(d,"/ogg")) then
	 table.insert(flacDirs,d)
      end
      if (string.match(d,"/mp3")) then
	 table.insert(flacDirs,d)
      end
      if (string.match(d,"/cmp")) then
	 table.insert(flacDirs,d)
      end
   end
   os.chdir(start)
end

-- returns 1 for each selected target format
function parseCvArg(arg)
   local cvfl,cvog,cvmp,cvcm
   for w in string.gmatch(arg,"%w+") do
      if (w=="flac") then
        cvfl=1
      end
      if (w=="ogg") then
        cvog=1
      end
      if (w=="mp3") then
        cvmp=1
      end
      if (w=="cmp") then
        cvcm=1
      end
   end
   return cvfl,cvog,cvmp,cvcm
end

-- display usage and exits
function usage()
   print ("Usage: ripcvt.lua [--target-format|-f format-list] [--target-dir|-d directory] [path]*")
   os.exit()
end

-- check that the argument is a proper directory
function checkdir(a_dir)
   exists,error=os.dir(a_dir)
   if (exists==nil) then
      usage()
   end
end


-- Parse all arguments
function parseArgs(arg, flacDirs, oggDirs, mp3Dirs, cmpDirs)
   local index=1
   local formatdone,dirdone,srcdone=0,0,0
   while (index <= #arg) do
      optdone=0
      if ((arg[index] == "--target-format") or (arg[index] == "-f")) then
	 index = index+1
	 if ((index > #arg) or (formatdone==1)) then
	    usage()
	 end
	 doflac,doogg,domp3,docmp = parseCvArg(arg[index])
	 formatdone=1
	 optdone=1
      end

      if ((arg[index] == "--target-dir") or (arg[index] == "-d")) then
	 index = index+1
	 if ((index > #arg) or (dirdone==1)) then
	    usage()
	 end
	 checkdir(arg[index])
	 targetdir=arg[index]
	 dirdone=1
	 optdone=1
      end

      if (optdone == 0) then
	 checkdir(arg[index])
	 getSrcDirs(arg[index], flacDirs, oggDirs, mp3Dirs, cmpDirs)
	 srcdone=1
      end

      index=index+1
   end

   if (srcdone == 0) then
      getSrcDirs(".", flacDirs, oggDirs, mp3Dirs, cmpDirs)
   end

   if (formatdone == 0) then
      doflac,doogg,domp3,docmp=0,1,1,1
   end

end



-- compute complete list of source directories
flacDirs={}
oggDirs={}
mp3Dirs={}
cmpDirs={}

parseArgs(arg, flacDirs, oggDirs, mp3Dirs, cmpDirs)


-- perform conversions from Flac sources
for i,d in ipairs(flacDirs) do
   flacdir,oggdir,mp3dir,cmpdir=dirs(d,"flac")
   convert(d,flacdir,oggdir,mp3dir,cmpdir)
end
-- perform conversions from Ogg sources
for i,d in ipairs(oggDirs) do
   flacdir,oggdir,mp3dir,cmpdir=dirs(d,"ogg")
   convert(d,flacdir,oggdir,mp3dir,cmpdir)
end
-- perform conversions from MP3 sources
for i,d in ipairs(mp3Dirs) do
   flacdir,oggdir,mp3dir,cmpdir=dirs(d,"mp3")
   convert(d,flacdir,oggdir,mp3dir,cmpdir)
end
-- perform conversions from CMP sources
for i,d in ipairs(cmpDirs) do
   flacdir,oggdir,mp3dir,cmpdir=dirs(d,"cmp")
   convert(d,flacdir,oggdir,mp3dir,cmpdir)
end
