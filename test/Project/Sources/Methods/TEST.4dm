//%attributes = {}
C_OBJECT:C1216($options)

$options:=New object:C1471("format";"hiragana")
$yomis:=Phonetics ("野茂英雄";$options)

$options:=New object:C1471("format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)

$options:=New object:C1471("format";"katakana";"width";"half")
$yomis:=Phonetics ("野茂英雄";$options)

  //detail:windows only; 形態素分解
$options:=New object:C1471("mode";"detail";"format";"katakana")
$yomis:=Phonetics ("野茂英雄";$options)
