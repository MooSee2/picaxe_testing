main_menu:
do
    SerOut 7, N9600, (CR, "--- Main Menu ---", CR)
    SerOut A.4, N9600_8, (_
        "Command | Action", CR, _
        "----------------", CR, _
        "1       | Return value at b0", CR, _
        "2       | Testing menu", CR, _
        "254     | Reset picaxe", CR, CR)
    SerOut A.4, N9600_8, ("Enter q<command>:  ")
    SerIn 0, N9600, ("q"), #b0
    SerOut A.4, N9600_8, (#b0, CR, CR, LF)
    if b0 = 1 then
        SerOut A.4, N9600_8, (#b0, CR, LF)
    elseif b0 = 2 then
        SerOut A.4, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    elseif b0 = 254 then
        reset
    else 
        SerOut A.4, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu
loop
