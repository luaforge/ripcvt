#!/usr/local/bin/lua

-- limitations de cette version: un seul argument répertoire

require ("ex")

function pos(str,char)
  for i=1,string.len(str),1 do
    if string.byte(str,i) == char then
      return i
    end
  end
  return 0
end

function decompose(dirname,list)
  p=pos(dirname,47)
  if (p ~= 0) then
    table.insert(list,string.sub(dirname,1,p-1))
    return decompose(string.sub(dirname,p+1,string.len(dirname)),list)
  else
    table.insert(list,dirname)
    return 1
  end
end

function dirs(name)
  os.mkdir("flac")
  os.mkdir("ogg")
  os.mkdir("mp3")
  top=os.currentdir()
  dirl={}
  decompose(name,dirl)
--[[  for i=1,#dirl,1 do
     print(dirl[i])
  end ]]
  if (os.chdir("flac")==true) then
     for i,d in ipairs(dirl) do
      os.chdir(d)
    end
    flacdir=os.currentdir()
 end
 os.chdir(top)
 if (os.chdir("ogg")==true) then
     for i,d in ipairs(dirl) do
      os.mkdir(d)
      os.chdir(d)
    end
    oggdir=os.currentdir()
  end
  os.chdir(top)
  if (os.chdir("mp3")==true) then
     for i,d in ipairs(dirl) do
	os.mkdir(d)
	os.chdir(d)
     end
     mp3dir=os.currentdir()
  end  
  os.chdir(top)
  return flacdir,oggdir,mp3dir
end


function basename (name,suffix)
   pos=string.find(name,suffix.."$")
   if (pos==nil) then
      return nil
   end
   return string.sub(name,1,pos-1)
end


rep=arg[1]
flacdir,oggdir,mp3dir=dirs(rep)
os.chdir(flacdir)
files=os.dir(".")
for current in os.dir(".") do
    title=basename(current.name,".flac")  
    if (current.type == "file") and (title ~= nil) then
       print("compressing "..title)
       p1=os.spawn("/usr/bin/oggenc",{args={"--quiet","-o",oggdir.."/"..title..".ogg",current.name}})
--       p=os.spawn("/bin/echo",{args={"-o",title..".ogg",current.name}})
       p2=os.spawn("/usr/bin/flac",{args={"--silent","-d","-f","-o","tempo.wav",current.name}})
       p2:wait()
       p3=os.spawn("/usr/bin/lame",{args={"--silent","--preset","cbr","128","tempo.wav",mp3dir.."/"..title..".mp3"}})
       p1:wait()    
       p3:wait()
    end 
end

--[[ old way of doing
current=files()
while current ~= nil do

      current=files()
end
]]

