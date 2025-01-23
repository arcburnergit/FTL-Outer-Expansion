C:
cd "C:\Users\aden\NEWADDON\FTL-Outer-Expansion"
echo %cd%
tar.exe -a -cf "FTL-Outer-Expansion.zip" audio data img mod-appendix
move /Y "C:\Users\aden\NEWADDON\FTL-Outer-Expansion\FTL-Outer-Expansion.zip" "C:\Program Files (x86)\Steam\steamapps\common\FTL Faster Than Light\Slipstream\mods"
cd "C:\Program Files (x86)\Steam\steamapps\common\FTL Faster Than Light\Slipstream"
modman.exe --patch "Multiverse 5.4.5 - Assets (Patch above Data).zip" "Multiverse 5.4.6  - Data.zip" "FTL-Outer-Expansion.zip"
exit