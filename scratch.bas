#PICAXE 28X2
#slot 0
setfreq m8

SYMBOL second = b2
SYMBOL minute = b3
SYMBOL hour = b4


main_menu:
    serTXD (CR, "--- Main Menu ---", CR)
    serTXD ("hour ex: 09", CR)
    serRXD hour
    serTXD ("hour is", #hour, CR)
    goto main_menu