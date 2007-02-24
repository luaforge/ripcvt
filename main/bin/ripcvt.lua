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
to accomodate Windows paths (again, LMKODIY).

RipCvt depends on the following programs: Flac, oggEnc, Lame.
It also depends on the "ex" Lua package (see 
  http://lua-users.org/files/wiki_insecure/users/MarkEdgar/exapi)

This is version 0.2. It is only able to convert from Flac to all of Ogg, Mp3-vbr
and Mp3-cbr.

Use is as:

ripcvt.lua [path]*

where each path has "flac" either as direct subdirectory or as a parent directory.
RipCvt will create "ogg", "mp3" and "cmp3" directories as brothers of this
"flac" directory. It will inspect all subdirectories of the given path to
find *.flac files in final subdirs (that is, subdirs without subdirs), build
the corresponding subtrees under "ogg", "mp3" and "cmp3", and convert the flac
files as expected into the "ogg", "mp3" and "cmp3" subtrees.
]]

require ("ex")

function pos(str,char)
   local i
   for i=1,string.len(str),1 do
      if string.byte(str,i) == char then
	 return i
      end
   end
   return 0
end

function decompose(dirname,list)
   local p=pos(dirname,47)
   if (p ~= 0) then
      table.insert(list,string.sub(dirname,1,p-1))
      return decompose(string.sub(dirname,p+1,string.len(dirname)),list)
   else
      table.insert(list,dirname)
      return 1
   end
end

-- compute ogg, mp3 and cmp3 dirs from srcDir
-- currently we support only flac as src dir
function dirs(srcDir)
   local flacpos=string.find(srcDir,"/flac")
   if ( not flacpos) then
      return nil,nil,nil
   end
   local top=string.sub(srcDir,1,flacpos-1)
   local relpath=string.sub(srcDir,flacpos+6)
   os.chdir(top)
   os.mkdir("ogg")
   os.mkdir("mp3")
   os.mkdir("cmp3")
   local dirl={}
   decompose(relpath,dirl)
   if (os.chdir("ogg")) then
      for i,d in ipairs(dirl) do
	 os.mkdir(d)
	 os.chdir(d)
      end
      oggdir=os.currentdir()
   end
   os.chdir(top)
   if (os.chdir("mp3")) then
      for i,d in ipairs(dirl) do
	 os.mkdir(d)
	 os.chdir(d)
      end
      mp3dir=os.currentdir()
   end  
   os.chdir(top)
   if (os.chdir("cmp3")) then
      for i,d in ipairs(dirl) do
	 os.mkdir(d)
	 os.chdir(d)
      end
      cmp3dir=os.currentdir()
   end  
   os.chdir(top)
   return srcDir,oggdir,mp3dir,cmp3dir
end


function basename (name,suffix)
   local pos=string.find(name,suffix.."$")
   if (pos==nil) then
      return nil
   end
   return string.sub(name,1,pos-1)
end


function convert(flacdir,oggdir,mp3dir,cmp3dir)
   local current
   local title
   os.chdir(flacdir)
   for current in os.dir(".") do
      title=basename(current.name,".flac")  
      if (current.type == "file") and (title ~= nil) then
	 print("compressing "..title)
	 p1=os.spawn("/usr/bin/oggenc",{args={"--quiet","-o",oggdir.."/"..title..".ogg",current.name}})
	 p2=os.spawn("/usr/bin/flac",{args={"--silent","-d","-f","-o","tempo.wav",current.name}})
	 p2:wait()
	 p3=os.spawn("/usr/bin/lame",{args={"--silent","--preset","standard","tempo.wav",mp3dir.."/"..title..".mp3"}})
	 p4=os.spawn("/usr/bin/lame",{args={"--silent","--preset","cbr","128","tempo.wav",cmp3dir.."/"..title..".mp3"}})
	 p1:wait()    
	 p3:wait()
	 p4:wait()
      end 
   end
   os.remove("tempo.wav")
end

-- get all final subdirs, that is, subdirs without subdirs themselves
function getAllSubDirs(dirs)
   local final=1
   local orig=os.currentdir()
   for current in os.dir(".") do
      if (current.type == "directory") then
	 final=nil
	 os.chdir(current.name)
	 getAllSubDirs(dirs)
	 os.chdir(orig)
      end
   end
   if (final) then
      table.insert(dirs,os.currentdir())
   end
end

-- compute a set of source dirs from one root
function getSrcDirs(root, flacDirs)
   local start=os.currentdir()
   os.chdir(root)
   local root=os.currentdir()
   local flacEnt=os.dirent("./flac")
   if ( (flacEnt ~= nil) and (flacEnt.type == "directory") ) then
      os.chdir("./flac")
      getAllSubDirs(flacDirs)
   else
      local flacpos=string.find(root,"/flac")
      if (flacpos) then
	 getAllSubDirs(flacDirs)
	 os.chdir(string.sub(root,1,flacpos-1))
      end
   end
   os.chdir(start)
end


-- compute complete list of source directories
flacDirs={}
if (#arg == 0) then
   getSrcDirs(".", flacDirs)
else
   for i=1,#arg,1 do
      getSrcDirs(arg[i], flacDirs)
   end
end

for i,d in ipairs(flacDirs) do
   print (d)
end



-- perform conversions
for i,d in ipairs(flacDirs) do
   flacdir,oggdir,mp3dir,cmp3dir=dirs(d)
   print (flacdir,oggdir,mp3dir)
   convert(flacdir,oggdir,mp3dir,cmp3dir)
end
