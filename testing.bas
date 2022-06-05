clear_terminal:
    SerOut b.7, N9600_8, (CR, CR, CR, CR, CR, CR, CR, CR, CR, CR)

main_menu:
    SerOut b.7, N9600_8, (CR, "--- Main Menu ---", CR)
    SerOut b.7, N9600_8, ("Command | Action", CR, "1) Return b0 varibale", CR, "2) testing menu", CR, "254) Reset picaxe", CR)
    SerOut b.7, N9600_8, ("Enter q<command>:  ")
    SerIn b.6, N9600_8, ("q"), #b0
    if b0 = 1 then
        SerOut b.7, N9600_8, (#b0, CR, LF)
    elseif b0 = 2 then
        SerOut b.7, N9600_8, (#b0, CR, LF, "Entering Testing Menu", CR)
        goto testing_menu
    elseif b0 = 254 then
        SerOut b.7, N9600_8, (#b0, CR, LF, "Entering Testing Menu", CR)
        reset
    else 
        SerOut b.7, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto main_menu

testing_menu:
    SerOut b.7, N9600_8, (CR, "--- Testing Menu ---", CR)
    SerOut b.7, N9600_8, ("1) Mouse", CR, "2) House", CR)
    SerOut b.7, N9600_8, ("Enter q<command>:  ")
    SerIn b.6, N9600_8, ("q"), #b0
    if b0 = 1 then
        SerOut b.7, N9600_8, (#b0, CR)
    elseif b0 = 2 then
        SerOut b.7, N9600_8, (#b0, CR)
    elseif b0 = 99 then
        SerOut b.7, N9600_8, (#b0, CR, " Returning to Main menu!", CR, LF)
        goto main_menu
    else 
        SerOut b.7, N9600_8, (CR, "Invalid input:  ", #b0, CR, LF)
    endif
    goto testing_menu