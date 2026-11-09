# Feel the Breeze — česká řeč k prezentaci

Kubernetes On Edge Day 2026 · Salt Lake City · 9. listopadu 2026.

Text odpovídá aktuální prezentaci se 17 slidy a celosvětovým srovnáním regionů. Slouží jako podklad k nácviku; obraty si přizpůsob vlastnímu způsobu mluvení. Hranaté závorky označují pokyny k přednesu a nečtou se nahlas. Představení je rozdělené mezi oba řečníky, zbytek používá „my“, aby jej mohl přednést kterýkoli z vás.

Slidy 11 a 12 jsou ponechané pro vlastní komentář k živému demu. Slide 17 obsahuje pouze volitelný úvod k záložnímu videu. Česká a [anglická verze](speaker-notes.en.md) jsou alternativy stejného vystoupení; během přednášky se použije jedna z nich.

Hlavní řeč má přibližně 1 650 slov, tedy orientačně **13–15 minut přednesu**, ke kterým připočítej živé demo, reakce publika a otázky. Vlastní čas si ověř jedním nácvikem nahlas.

Hlavní sdělení: **Stejnou užitečnou práci můžeme udělat s menšími emisemi, když změříme její spotřebu a vhodně zvolíme, kdy a kde poběží.** Zdroje a předpoklady výpočtů jsou v [README prezentace](README.md#data-and-assumptions). Text zachovává rozlišení mezi měřením, modelovým příkladem a prognózou.

## 01 — Feel the Breeze

Ahoj všem a vítejte na Feel the Breeze v rámci Kubernetes On Edge Day. Jsme David a Petr a na naši přednášku jsme přivezli solární panel, Raspberry Pi a ventilátor.

Ten hardware tu má praktický důvod. Energie je obvykle schovaná za cloudovým API. Vytvoříme deployment, nastavíme počet replik a na konci měsíce vidíme účet. Elektřina, která za těmito rozhodnutími stojí, je mnohem méně viditelná.

Dnes chceme tyto dva světy propojit. Hlavní myšlenka je jednoduchá: stejnou užitečnou práci můžeme udělat s menšími emisemi, pokud rozumíme její spotřebě a můžeme ovlivnit, kdy a kde poběží.

Začneme motivací, podíváme se na měření a potom si řídicí smyčku ukážeme přímo tady na pódiu.

## 02 — Who

**David:** Já jsem David Pech. Baví mě Kubernetes, automatizace a hledání toho, jak do sebe jednotlivé části platformy zapadají.

**Petr:** Já jsem Petr Rais. Jsem softwarový inženýr, zajímám se o DevOps a o propojení aplikací s infrastrukturou, na které běží.

**Kdokoli z vás:** Tenhle projekt nám umožňuje zkoumat toto propojení na něčem, na co si můžeme sáhnout. Používáme známé cloud native nástroje, ale výsledkem je fyzické zařízení reagující na měnící se energetický signál.

Začněme jedním rozhodnutím o spotřebě energie, které už udělal každý v téhle místnosti.

## 03 — How did you get here?

Na začátek malá anketa: kdo sem přiletěl? Kdo přijel autem? A kdo jel z letiště vlakem?

[Nech prostor pro zvednutí rukou.]

Všichni máme představu, že cesta mezi dvěma místy může mít různou uhlíkovou stopu podle toho, jaký způsob dopravy zvolíme. Tady k tomu přidáváme několik orientačních čísel.

Používáme standardní emisní faktory a zaokrouhlené vzdálenosti. U vlaku jde o americký průměr a letecké hodnoty nezahrnují další klimatické vlivy mimo CO₂. Jsou to příklady pro představu o velikosti, ne osobní vyúčtování vaší cesty.

A teď se podívejte na příklad s podem. Pokud trvale běžícímu workloadu přiřadíme pět wattů, za rok to znamená přibližně čtyřicet čtyři kilowatthodin. S uvedeným emisním faktorem pro Salt Lake City vychází zhruba dvacet pět kilogramů ekvivalentu CO₂, bez režie datacentra.

Pět wattů je tady předpoklad. Zajímavá otázka zní: kolik takových drobných, nepřetržitě běžících workloadů máme v clusterech a kolik užitečné práce odvádějí?

## 04 — Even hyperscalers hit the wall

Ve velikosti datacenter už se z toho stává fyzické omezení.

Zpráva IEA z roku 2026 uvádí přibližně čtyři sta osmdesát pět terawatthodin elektřiny spotřebované datacentry v roce 2025. Pro rok 2030 předpokládá zhruba devět set padesát. To druhé číslo je prognóza s určitou nejistotou, ale dobře ukazuje velikost problému.

Další výpočetní kapacita potřebuje také připojení do sítě, transformátory, povolení a místo v místním energetickém systému. To všechno má jinou dobu realizace než nasazení softwaru.

Z Kubernetes manifestu celý problém nevyřešíme. Můžeme ale omezit nevyužitou kapacitu a vhodným workloadům dát větší flexibilitu.

To je naše část problému: kolik práce opravdu musí běžet nepřetržitě, jak efektivně běží a jakou máme volnost v čase a místě jejího provedení?

Abychom to mohli zkoumat, postavili jsme malý systém, který můžeme přivézt na pódium.

## 05 — Kubernetes that fits in your pocket

Náš edge cluster běží na Raspberry Pi se dvěma gigabajty paměti a používá k0s. Na malém fyzickém zařízení tak máme Kubernetes API a nástroje, které už známe.

Argo CD, Prometheus a Grafanu necháváme v centrálním clusteru, kterému říkáme HQ. Na Raspberry je proto nemusíme provozovat znovu.

Konfigurace je popsaná v našem projektu feel-the-breeze, na který vede odkaz dole na slidu. Nastavení Raspberry Pi a centrálního clusteru najdete v adresářích pi a hq. Zařízení můžeme znovu připravit a synchronizovat jeho workloady, přičemž přístupové údaje k zařízením obnovujeme samostatně.

Pro tuto přednášku je Raspberry naše experimentální platforma. Díky malé velikosti je dobře vidět vztah mezi softwarem a fyzickým hardwarem. Skutečnou spotřebu i paměťové nároky je přesto potřeba změřit na konkrétním zařízení.

A takhle jej spravujeme z centrálního clusteru.

## 06 — One HQ, N edge clusters

Argo CD v HQ se připojuje ke Kubernetes API edge clusteru a spravuje v něm deklarované aplikace. Prometheus sbírá metriky a v Grafaně je můžeme sledovat.

Diagram ukazuje, jak se tento způsob správy dá rozšířit na více lokalit. ApplicationSety mohou vytvářet aplikace pro registrované clustery a centrální služby se sdílejí napříč celým prostředím.

Pro naši ukázku používáme jeden fyzický edge cluster. Více lokalit v diagramu ilustruje princip správy.

Pro naše téma je důležité propojení s observabilitou: potřebujeme vidět, co workload dělá, a potom umět jeho chování změnit opakovatelným způsobem.

Tím máme připravenou smyčku pro správu. Teď ještě potřebujeme energetický signál, kterému dokážeme správně porozumět.

## 07 — Project Kepler

Kepler exportuje metriky související s energií a pomáhá nám propojit workloady se spotřebou hardwaru.

Současná upstream architektura na tomto slidu používá hardwarová měření energie a informace o procesorovém čase, podle kterých přiřazuje spotřebu jednotlivým workloadům. Oproti starší architektuře s eBPF a modelovým serverem se změnila, proto záleží na verzi i odpovídající dokumentaci.

Důležitý pojem je přiřazení spotřeby. Hodnota pro konkrétní pod představuje podíl určený nějakou metodou. Každý pod nemá vlastní fyzický elektroměr.

Naše demo na Raspberry používá starší Helm chart a hodnoty Kepleru jsou modelové odhady, protože v této sestavě nemáme k dispozici potřebné hardwarové čítače. USB tester samostatně měří výkon ze solárního panelu.

Oba signály mohou být užitečné, když vysvětlíme, co představují. Než podle čísla začneme rozhodovat, měli bychom znát jeho zdroj, kterou část hardwaru pokrývá a jak bylo přiřazeno workloadu.

## 08 — Watts are a signal. Work is the denominator.

Máme tady tři kroky: měřit, přiřadit a porovnat.

Watty popisují příkon v konkrétním okamžiku. Pro spotřebu energie celé úlohy potřebujeme vědět, jak se příkon vyvíjel během jejího běhu. Nižší okamžitá hodnota může vést k vyšší spotřebě energie, pokud úloha poběží výrazně déle.

Pak potřebujeme vědět, kde měříme. Sledujeme procesor, celý uzel, nebo větší systém? Jak se spotřeba rozděluje mezi workloady? A co se děje se základní spotřebou stroje, i když zrovna nic nezpracovává?

Nakonec porovnáváme stejný užitečný výsledek: dokončenou úlohu, určitý počet úspěšných požadavků nebo zpracovaný dataset, při stejných požadavcích na službu.

Provozní emise spočítáme ze spotřeby energie a uhlíkové intenzity elektřiny. Úplnější pohled zahrnuje i emise spojené s výrobou hardwaru.

Proto nás zajímá energie a emise na užitečný výsledek. Teprve pak můžeme smysluplně vyhodnotit optimalizaci.

## 09 — Move the work, keep the deadline

Pojďme si rozhodnutí o čase ukázat na konkrétním příkladu.

Představte si úlohu, která spotřebuje sto kilowatthodin. Při emisním faktoru pět set gramů ekvivalentu CO₂ na kilowatthodinu vznikne padesát kilogramů provozních emisí. Pokud stejná úloha spotřebuje stejnou energii v době, kdy je faktor sto gramů, dostaneme deset kilogramů.

V tomto hypotetickém příkladu je to snížení o osmdesát procent. Ukazuje princip výpočtu; nejde o naměřený výsledek našeho dema.

V praxi potřebujeme zjistit, jestli má workload takovou flexibilitu. Dávková analytika, zpracování videa nebo méně urgentní zálohy mohou mít prostor pro posun. Stále ale potřebujeme deadline, maximální dobu čekání ve frontě a postup pro případ chybějících nebo zastaralých dat.

Jednou z možností implementace je Carbon Aware KEDA Operator. Podle externí předpovědi může upravovat povolený strop počtu replik, zatímco KEDA dál vyhodnocuje potřebu škálování.

Úspěch znamená dokončit stejnou práci včas a započítat i režii, kterou změna přinesla.

## 10 — CNCF Environmental Sustainability

Těmito otázkami se zabývá i komunita, ve které můžeme sdílet svoje experimenty.

Původní TAG Environmental Sustainability pokračuje jako Technical Community Group. Věnuje se energetickým a uhlíkovým metrikám, nástrojům jako Kepler a sdílení praktických zkušeností.

Green Reviews dnes spadá pod TAG Operational Resilience a podporuje systematické hodnocení spotřeby prostředků a energie u cloud native projektů.

Přispět můžete opakovatelným experimentem: co jste spustili, na jakém hardwaru, jak jste měřili a co se změnilo.

Právě tyto podrobnosti umožňují ostatním výsledek zopakovat a pochopit, kde se dá použít. Naše hardwarová sestava je jeden ze způsobů, jak takovou diskusi začít. Pojďme si tu řídicí smyčku ukázat naživo.

## 11 — Demo time!

[Živé demo. Vlastní komentář podle průběhu ukázky; bez připravené řeči.]

## 12 — The solar + fan control loop

[Živé demo a vysvětlení architektury. Vlastní komentář podle průběhu ukázky; bez připravené řeči.]

## 13 — Key takeaways

Naše sestava propojuje tři myšlenky.

Zaprvé, i malé edge zařízení můžeme zapojit do známého způsobu správy Kubernetes. Experimentování s fyzickými zařízeními je tak dostupné pomocí nástrojů, které už používáme.

Zadruhé, příkon a spotřeba energie mohou být součástí observability. Aby nám metriky pomohly, musíme vysvětlit rozsah měření, způsob přiřazení a případné odhady a propojit je s dokončenou prací.

Zatřetí, u flexibilních workloadů můžeme rozhodovat také o tom, kdy a kde poběží, při zachování termínu a požadované úrovně služby.

Hardware ukazuje reakci na dostupnost obnovitelné energie. Skutečnou úsporu emisí bychom ověřovali pomocí vhodného uhlíkového signálu a porovnání stejné užitečné práce před změnou a po ní.

Mluvili jsme o posouvání v čase. Než skončíme, podívejme se ještě na rozhodování o místě, tentokrát celosvětově.

## 14 — Same VM, different region

Toto srovnání zahrnuje šest kontinentů. V každém řádku předpokládáme stejnou roční spotřebu energie a měníme regionální emisní faktor elektřiny.

Označení virtuálního stroje dává příkladu konkrétní velikost, ale přiřazených osmdesát wattů i režie datacentra jsou modelové předpoklady. Nejde o naměřenou spotřebu tohoto typu stroje.

S publikovanými faktory Googlu za rok 2025 vychází v našem modelu přibližně dvanáct kilogramů ekvivalentu CO₂ pro Paříž, čtyři sta třicet osm pro Salt Lake City a čtyři sta devadesát čtyři pro Johannesburg. Mezi nejnižším a nejvyšším příkladem na tomto slidu je tedy přibližně čtyřicetinásobný rozdíl.

Jsou to roční průměry místních elektrických sítí. Mají jiný účel než hodinová předpověď pro plánování úloh nebo vykázaná uhlíková stopa zákazníka cloudu.

Při rozhodování musíme zohlednit také latenci, dostupnou kapacitu a požadavky na umístění dat. V rámci těchto omezení může být volba regionu významnou částí výpočtu.

Dalším krokem je ověřit to na workloadu, kterému rozumíme.

## 15 — Try it this week

Začněte jedním podporovaným uzlem a jedním workloadem. Ověřte, které energetické senzory máte k dispozici a co na dané sestavě Kepler skutečně exportuje.

Příkaz na slidu ukazuje současný upstream postup instalace. Naše demo na Raspberry používá starší chart společně s odpovídajícím dashboardem. Proto si pohlídejte, aby metriky a dokumentace odpovídaly nasazené verzi.

Vyberte workload s měřitelným výstupem a určitou volností v plánování. Zaznamenejte spotřebu energie, dokončenou práci, dobu běhu a splnění požadavků na službu.

Pak změňte jednu věc: třeba dobu spuštění nebo vhodný region. Zopakujte stejnou práci a porovnejte výsledek, včetně dodatečných přenosů dat, restartů nebo režie čekání.

Pokud chcete snížit i základní spotřebu uzlu, ověřte, jestli infrastruktura dokáže workloady konsolidovat a nepotřebné stroje vypnout.

Jeden opakovatelný výsledek před změnou a po ní vám dá podklad pro rozhodnutí, co zkoušet dál.

## 16 — Thank you

Pokud si z dneška odnesete jednu myšlenku, ať je to tato: měřte energii potřebnou pro užitečnou práci a potom využijte volnost, kterou máte v tom, kdy a kde poběží.

QR kód vede do repozitáře s demem a prezentací. Jsou tam i předpoklady výpočtů a zdroje, takže si je můžete projít nebo experiment přizpůsobit.

Děkujeme, že jste přišli. Rádi uslyšíme, na jakém workloadu byste to zkusili vy a jaká omezení byste potřebovali dodržet.

A pokud se chcete podívat na hardware zblízka, přijďte si ten vánek vyzkoušet na vlastní kůži.

[Prostor pro otázky. Konec hlavní přednášky; na slide 17 pokračuj jen v případě potřeby.]

## 17 — Backup Video

[Volitelné. Použij pouze při přechodu na záznam během dema. Potom se vrať k vysvětlení nebo pokračuj slidem 13.]

Máme připravený záznam stejné sestavy, takže můžeme ukázat chování, o kterém chceme mluvit. Sledujte v něm propojení mezi měnícím se vstupním signálem, rozhodnutím o škálování a fyzickým zařízením.
