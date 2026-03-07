"Bon Sang" : application de suivi de la glycémie conçue pour les diabétiques.

- Affichage d'un graphique simple permettant de visualiser le niveau de sucre dans le sang.
- Ajout de plusieurs fonctionnalités ayant pour but de faciliter le suivi de l'alimentation et des activités :
    - Ajout de photos des repas, saisie d'informations relatives au sport, etc.
- Simples améliorations à apporter qui n'existent même pas dans les applications officielles de Dexcom :
    - Affichage des valeurs en mmol/L et en mg/dL en même temps. (En Europe, on mesure la glycémie en mmol/L alors qu'aux États-Unis on utilise mg/dL. Cela peut parfois entraîner des difficultés de compréhension. La conversion est cependant très simple : x mmol/L = 18*x mg/dL.)
    - Affichage de l'heure du dernier relevé ainsi que de celle du prochain. Les Capteurs de Glucose en Continu (CGC) mesurent la glycémie toutes les cinq minutes, mais il peut être utile de connaître l'heure du prochain relevé pour adapter le traitement. Savoir quand arrivera cette mesure peut donc être pratique (et c'est simple à implémenter).
- Éventuelle superposition de plusieurs graphiques permettant aux utilisateurs de comparer leur glycémie avec celle d'autres diabétiques. Cela pourrait se révéler très utile lorsque deux diabétiques essaient de comprendre les différents impacts de certains aliments. L'alimentation est très importante chez les diabétiques, mais tout le monde est différent et un même repas peut avoir des effets très différents sur la glycémie selon les personnes. Il existe en effet de nombreux paramètres qui font varier la glycémie, notamment :
        - L'activité sportive
        - L'alimentation
        - Le sommeil
        - Le stress
        - L'heure de la journée
        - Le niveau d'insuline déjà présent dans le sang
        - Une éventuelle déshydratation ou d'autres maladies
        - L'alcool / la caféine
        - etc.
    Pour bien adapter son traitement, il est important de comprendre l'impact de tous ces facteurs sur son corps. On comprend donc l'intérêt de faciliter le suivi de ces paramètres, ainsi que celui de superposer les graphiques d'autres diabétiques.
- Idéalement : récupération de fausses données à l'aide de l'API Sandbox de Dexcom. Sinon, il serait possible de générer des données fictives au lieu d'utiliser l'API.
