$test=new-object system.directoryservices.directorysearcher("name=$(hostname)")
($test.findone()).Path
