import  sys
import  zipfile

def main (Filename, pathTo):
    with zipfile.ZipFile( Filename ) as  Zip:
        for  Info  in  Zip.infolist ():
            Info . filename  =  Info . filename . decode ( 'Shift-Jis' ) . encode ( 'Utf-8' )
            Zip . extract ( Info, pathTo )

if  __name__  ==  '__main__' :
    sys . exit ( main ( sys . argv [ 1 ], sys . argv [ 2 ]))
