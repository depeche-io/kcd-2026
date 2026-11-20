# Feel the Breeze — česká řeč k prezentaci

Techmeetup Ostrava 2026 · Ostrava-Poruba · 20. listopadu 2026.

Text odpovídá aktuálnímu [PDF prezentace](feel-the-breeze.pdf) s 20 slidy, včetně přiblížení velikosti 1 TWh, týdenního průběhu uhlíkové intenzity britské sítě a celosvětového srovnání regionů. Slouží jako podklad k nácviku; obraty si přizpůsob vlastnímu způsobu mluvení. Hranaté závorky označují pokyny k přednesu a nečtou se nahlas. Představení je rozdělené mezi oba řečníky, zbytek používá „my“, aby jej mohl přednést kterýkoli z vás.

Slidy 13 a 14 jsou ponechané pro vlastní komentář k živému demu. Na slidu 15 je otázka pro publikum; odpověď následuje na slidu 16. Slide 20 obsahuje pouze volitelný úvod k záložnímu videu. Česká a [anglická verze](speaker-notes.en.md) jsou alternativy stejného vystoupení; během přednášky se použije jedna z nich.

Hlavní řeč má přibližně 2 400 slov, tedy orientačně **17–20 minut přednesu** při tempu 120–140 slov za minutu. K tomu připočítej živé demo, reakce publika a otázky. Vlastní čas si ověř jedním nácvikem nahlas.

Hlavní sdělení: **Stejnou užitečnou práci můžeme udělat s menšími emisemi, když změříme její spotřebu a vhodně zvolíme, kdy a kde poběží.** Zdroje jsou uvedené přímo na slidech a ve [zdroji prezentace](slides.md); další podrobnosti k výpočtům jsou v [README prezentace](README.md#data-and-assumptions). Text zachovává rozlišení mezi měřením, modelovým příkladem a prognózou.

## 01 — Feel the Breeze

Ahoj všem a vítejte na Feel the Breeze na Techmeetupu v Ostravě. Jsme David a Petr a na naši přednášku jsme přivezli solární panel, Raspberry Pi a ventilátor.

Ten hardware tu má praktický důvod. Energie je obvykle schovaná za cloudovým API. Vytvoříme deployment, nastavíme počet replik a na konci měsíce vidíme účet. Elektřina, která za těmito rozhodnutími stojí, je mnohem méně viditelná.

Dnes chceme tyto dva světy propojit. Hlavní myšlenka je jednoduchá: stejnou užitečnou práci můžeme udělat s menšími emisemi, pokud rozumíme její spotřebě a můžeme ovlivnit, kdy a kde poběží.

Začneme motivací, podíváme se na měření a potom si řídicí smyčku ukážeme přímo tady na pódiu.

## 02 — Who

**David:** Já jsem David Pech. Baví mě Kubernetes, automatizace a hledání toho, jak do sebe jednotlivé části platformy zapadají.

**Petr:** Já jsem Petr Rais. Jsem softwarový inženýr, zajímám se o DevOps a o propojení aplikací s infrastrukturou, na které běží.

**Kdokoli z vás:** Tenhle projekt nám umožňuje zkoumat toto propojení na něčem, na co si můžeme sáhnout. Používáme známé cloud native nástroje, ale výsledkem je fyzické zařízení reagující na měnící se energetický signál.

Začněme jedním rozhodnutím o spotřebě energie, které už udělal každý v téhle místnosti.

## 03 — How did you get here?

Na začátek malá anketa: kdo přijel do Ostravy autem? Kdo vlakem nebo autobusem? A kdo dnes využil tramvaj nebo přišel pěšky?

[Nech prostor pro zvednutí rukou.]

Všichni máme představu, že cesta mezi dvěma místy může mít různou uhlíkovou stopu podle toho, jaký způsob dopravy zvolíme. Tady k tomu přidáváme několik orientačních čísel pro cesty do Ostravy.

Například pro cestu z Prahy počítáme přibližně tři sta sedmdesát kilometrů autem nebo tři sta padesát kilometrů vlakem. Z Brna je tu příklad cesty autobusem a ze Svinova krátká cesta tramvají k VŠB. Vzdálenosti jsou zaokrouhlené a pro srovnání používáme britské referenční emisní faktory DESNZ. Nejde o naměřené emise českých dopravců ani o přesný výpočet konkrétního spoje. Chůze má v tomto srovnání nulové přímé provozní emise.

A teď se podívejte na příklad s podem. Pokud trvale běžícímu workloadu přiřadíme pět wattů, za rok to znamená přibližně čtyřicet čtyři kilowatthodin. S českým faktorem výroby elektřiny za rok 2025 od MPO vychází zhruba čtrnáct a půl kilogramu CO₂, bez režie datacentra. Je to celostátní orientační faktor, ne měření ostravské spotřeby.

Pět wattů je tady předpoklad. Zajímavá otázka zní: kolik takových drobných, nepřetržitě běžících workloadů máme v clusterech a kolik užitečné práce odvádějí?


## 04 — Even hyperscalers hit the wall

Ve velikosti datacenter už se z toho stává fyzické omezení.

Zpráva IEA z roku 2026 uvádí přibližně čtyři sta osmdesát pět terawatthodin elektřiny spotřebované datacentry v roce 2025, s meziročním růstem o sedmnáct procent. Pro rok 2030 předpokládá zhruba devět set padesát terawatthodin, přibližně tři procenta světové poptávky po elektřině. To druhé číslo je prognóza s určitou nejistotou, ale dobře ukazuje velikost problému.

Další výpočetní kapacita potřebuje také připojení do sítě, transformátory, povolení a místo v místním energetickém systému. To všechno má jinou dobu realizace než nasazení softwaru.

Přidává se i odpor místních obyvatel. Srpnový průzkum Heatmap a Embold na slidu uvádí sedmdesát pět procent amerických voličů proti datacentru v jejich okolí, oproti čtyřiceti dvěma procentům o rok dříve. Samostatný březnový průzkum Gallupu uvádí sedmdesát jedna procent proti místnímu datacentru a padesát tři proti jaderné elektrárně. Jsou to dva různé průzkumy; společně ilustrují i společenskou stránku výstavby.

Z Kubernetes manifestu celý problém nevyřešíme. Můžeme ale omezit nevyužitou kapacitu a vhodným workloadům dát větší flexibilitu.

To je naše část problému: kolik práce opravdu musí běžet nepřetržitě, jak efektivně běží a jakou máme volnost v čase a místě jejího provedení?

Než se podíváme na naši malou sestavu, dejme těm terawatthodinám konkrétnější měřítko.

## 05 — How much is 1 TWh?

Jedna terawatthodina je miliarda kilowatthodin. Datacentra jich za rok 2025 spotřebovala přibližně čtyři sta osmdesát pět. Co ale znamená jedna?

První přirovnání je asi pět set třicet startů Falconu 9. Tady porovnáváme chemickou energii paliva, přibližně jednu celou devět desetin gigawatthodiny na start. Není to elektrická spotřeba rakety ani energie skutečně převedená na její pohyb.

U stolního počítače s předpokládaným příkonem sto wattů je to deset miliard hodin provozu. Jinými slovy, zhruba milion sto tisíc takových počítačů zapnutých nepřetržitě po celý rok.

Třetí přirovnání používá publikované hodnoty pro textové AI dotazy: dvacet čtyři až třicet čtyři setin watthodiny na dotaz. Při těchto hodnotách vychází jedna terawatthodina asi na tři až čtyři biliony dotazů. Jde o medián pro Gemini a průměr pro ChatGPT z různých zdrojů, ne o univerzální spotřebu každého dotazu.

Jeden dotaz je malý. Při bilionech opakování už záleží na spotřebě jednotlivých úloh i na elektřině, kterou používají. Pojďme se podívat, jak takové úlohy spravujeme na edge.

## 06 — Efficient edge fleet: one HQ, N edge clusters

Centrálnímu clusteru říkáme HQ. Argo CD v něm se připojuje ke Kubernetes API edge clusteru a spravuje v něm deklarované aplikace. Edge zaregistrujeme pomocí tokenu ServiceAccountu; samostatný agent Argo CD na něm neběží. Prometheus v HQ sbírá metriky přes proxy API serveru a v Grafaně je můžeme sledovat.

Diagram ukazuje, jak se tento způsob správy dá rozšířit na více lokalit. ApplicationSety mohou vytvářet aplikace pro registrované clustery a centrální služby se sdílejí napříč celým prostředím.

Pro naši ukázku používáme jeden fyzický edge cluster. Více lokalit v diagramu ilustruje princip správy.

Pro naše téma je důležité propojení s observabilitou: potřebujeme vidět, co workload dělá, a potom umět jeho chování změnit opakovatelným způsobem.

Sdílením centrálních služeb rozložíme jejich režii mezi více lokalit. Vhodné workloady také můžeme mimo potřebné hodiny pozastavit. Teď si přibližme jedno konkrétní zařízení v této architektuře.

## 07 — Kubernetes that fits in your pocket

Náš edge cluster běží na Raspberry Pi 4 s architekturou ARM64, dvěma gigabajty paměti a distribucí k0s. Na malém fyzickém zařízení tak máme řídicí rovinu i worker, Kubernetes API a nástroje, které už známe.

Argo CD, Prometheus a Grafanu necháváme v HQ. Na Raspberry je proto nemusíme provozovat znovu.

Konfigurace je popsaná v našem projektu feel-the-breeze, na který vede odkaz dole na slidu. Nastavení Raspberry Pi a centrálního clusteru najdete v adresářích pi a hq. Obnova začíná nahráním Ubuntu a použitím cloud-initu. Potom nainstalujeme k0s, zaregistrujeme zařízení v HQ a Argo CD synchronizuje deklarované workloady. Přístupové údaje k zařízením obnovujeme samostatně.

Pro tuto přednášku je Raspberry naše experimentální platforma. Díky malé velikosti je dobře vidět vztah mezi softwarem a fyzickým hardwarem. Skutečnou spotřebu i paměťové nároky je přesto potřeba změřit na konkrétním zařízení.

Tím máme připravenou smyčku pro správu. Teď ještě potřebujeme energetický signál, kterému dokážeme správně porozumět.

## 08 — Project Kepler

Kepler exportuje metriky související s energií a pomáhá nám propojit workloady se spotřebou hardwaru.

Slide uvádí upstream verzi 0.13.0 ze šestého listopadu 2026. Tato architektura používá hardwarová měření energie a informace o procesorovém čase z procfs a sysfs, podle kterých přiřazuje spotřebu jednotlivým workloadům. Podporuje RAPL a experimentálně také hwmon, GPU a Redfish. Nevyžaduje eBPF; návrh s eBPF a modelovým serverem patří ke starší architektuře do verze 0.9. Verze 0.12 přidala ARM64 obrazy, záložní čtení přes hwmon a přiřazení spotřeby MIG přes DCGM. Proto záleží na verzi i odpovídající dokumentaci.

Důležitý pojem je přiřazení spotřeby. Hodnota pro konkrétní pod představuje podíl určený nějakou metodou. Každý pod nemá vlastní fyzický elektroměr.

Naše demo na Raspberry používá starší Helm chart 0.5.10 a hodnoty Kepleru jsou modelové odhady, protože v této sestavě nemáme k dispozici potřebné hardwarové čítače. USB tester samostatně měří výkon ze solárního panelu.

Oba signály mohou být užitečné, když vysvětlíme, co představují. Než podle čísla začneme rozhodovat, měli bychom znát jeho zdroj, kterou část hardwaru pokrývá a jak bylo přiřazeno workloadu.

## 09 — The same kWh is not the same carbon

Spotřeba energie je ale jen jedna část výpočtu. Uhlíková intenzita říká, kolik emisí připadá na jednu kilowatthodinu, a v čase se mění.

Tady vidíte skutečný týden britské elektrické sítě, od dvacátého šestého října do prvního listopadu 2026. Data pocházejí z NESO Carbon Intensity API. Graf zobrazuje hodinové průměry půlhodinových hodnot v UTC, v gramech CO₂ na kilowatthodinu.

Ve větrné úterý hodnota klesla přibližně na padesát dva gramů. Ve čtvrtek ráno, při slabším větru a větším podílu plynu, vystoupala na dvě stě třicet dva. V jednom týdnu je to zhruba čtyřapůlnásobný rozdíl pro stejnou kilowatthodinu.

Schéma vpravo připomíná přečerpávací elektrárnu. Když je elektřina čistší a levnější, čerpá vodu nahoru. Ve špičce ji pouští dolů a vyrábí elektřinu. Naše flexibilní úloha může podobně využít vhodnější hodiny tím, že do nich přesune svůj běh. Výpočet tím neskladuje elektřinu; přesouvá poptávku v čase.

Je to historický průběh, ne předpověď pro dnešní demo. Pro plánování dopředu potřebujeme vhodný aktuální signál a omezení konkrétní úlohy. Nejdřív si ale ujasněme, co budeme porovnávat.

## 10 — Watts are a signal. Work is the denominator.

Máme tady tři kroky: měřit, přiřadit a porovnat.

Watty popisují příkon v konkrétním okamžiku. Pro spotřebu energie celé úlohy potřebujeme vědět, jak se příkon vyvíjel během jejího běhu. Nižší okamžitá hodnota může vést k vyšší spotřebě energie, pokud úloha poběží výrazně déle.

Pak potřebujeme vědět, kde měříme. Sledujeme procesor, celý uzel, nebo větší systém? Jak se spotřeba rozděluje mezi workloady? A co se děje se základní spotřebou stroje, i když zrovna nic nezpracovává?

Nakonec porovnáváme stejný užitečný výsledek: dokončenou úlohu, určitý počet úspěšných požadavků nebo zpracovaný dataset, při stejných požadavcích na službu.

Provozní emise spočítáme ze spotřeby energie a uhlíkové intenzity elektřiny. Úplnější pohled zahrnuje i emise spojené s výrobou hardwaru.

Proto nás zajímá energie a emise na užitečný výsledek. Teprve pak můžeme smysluplně vyhodnotit optimalizaci.

## 11 — Move the work, keep the deadline

Pojďme si rozhodnutí o čase ukázat na konkrétním příkladu.

Představte si úlohu, která spotřebuje sto kilowatthodin. Při emisním faktoru pět set gramů ekvivalentu CO₂ na kilowatthodinu vznikne padesát kilogramů provozních emisí. Pokud stejná úloha spotřebuje stejnou energii v době, kdy je faktor sto gramů, dostaneme deset kilogramů.

V tomto hypotetickém příkladu je to snížení o osmdesát procent. Ukazuje princip výpočtu; nejde o naměřený výsledek našeho dema.

V praxi potřebujeme zjistit, jestli má workload takovou flexibilitu. Dávková analytika, CI, zpracování videa nebo méně urgentní zálohy mohou mít prostor pro posun. Stále ale potřebujeme deadline, maximální dobu čekání ve frontě, požadovanou úroveň služby, pravidla pro umístění dat a postup pro případ chybějících nebo zastaralých signálů.

Jednou z možností implementace je Carbon Aware KEDA Operator. Podle externí předpovědi může upravovat povolený strop počtu replik, zatímco KEDA dál vyhodnocuje potřebu škálování.

Úspěch znamená dokončit stejnou práci včas a započítat i režii, kterou změna přinesla.

## 12 — CNCF Environmental Sustainability

Těmito otázkami se zabývá i komunita, ve které můžeme sdílet svoje experimenty.

Původní TAG Environmental Sustainability pokračuje jako Technical Community Group. Věnuje se energetickým a uhlíkovým metrikám, nástrojům jako Kepler a sdílení praktických zkušeností.

Zapojit se můžete přes Cloud Native Sustainability Month nebo kanál #tcg-environmental-sustainability na CNCF Slacku. Odkaz na aktuální setkání je dole na slidu.

Green Reviews dnes spadá pod TAG Operational Resilience a podporuje systematické hodnocení spotřeby prostředků a energie u cloud native projektů.

Přispět můžete opakovatelným experimentem: co jste spustili, na jakém hardwaru, jak jste měřili a co se změnilo.

Právě tyto podrobnosti umožňují ostatním výsledek zopakovat a pochopit, kde se dá použít. Naše hardwarová sestava je jeden ze způsobů, jak takovou diskusi začít. Pojďme si tu řídicí smyčku ukázat naživo.

## 13 — Demo time!

[Živé demo. Vlastní komentář podle průběhu ukázky; bez připravené řeči.]

## 14 — The solar + fan control loop

[Živé demo a vysvětlení architektury. Vlastní komentář podle průběhu ukázky; bez připravené řeči.]

## 15 — How would you cut your cloud VM’s CO₂?

Právě jsme ukázali reakci na dostupnost sluneční energie. Teď si představte jeden virtuální stroj v cloudu, který běží nepřetržitě. Jak byste začali snižovat jeho emise?

Zmenšili byste paměť? Vybrali menší stroj? Přešli z x86 na ARM? Vypínali ho mimo pracovní dobu, dávali více podů na jeden uzel, nebo změnili region?

[Nech zaznít dvě až tři odpovědi. Zatím nepřepínej na další slide.]

Každá z těch možností může mít smysl. Paměť a nevyužité procesory mají svoji spotřebu. Při čtyřicetihodinovém pracovním týdnu zbývá sto dvacet osm hodin, kdy stroj možná vůbec nepotřebujeme. Konsolidace může umožnit vypnutí celých uzlů. U změny architektury potřebujeme ověřit, kolik stejné práce skutečně uděláme na jednotku energie.

Máme tedy možnosti, které mění spotřebu energie, i možnosti, které mění emise připadající na kilowatthodinu. Která z nich může v našem příkladu udělat přibližně čtyřicetinásobný rozdíl?

[Krátká pauza na tipy, potom přepni na srovnání regionů.]

## 16 — Same VM, different region

Tady je odpověď: region. Toto srovnání zahrnuje šest kontinentů. V každém řádku předpokládáme stejnou roční spotřebu energie a měníme regionální emisní faktor elektřiny.

Používáme označení n4-standard-8, osm virtuálních procesorů a třicet dva gigabajtů paměti. Přiřazených osmdesát wattů i PUE jedna celá jedna jsou modelové předpoklady. Za rok z nich vychází přibližně sedm set sedmdesát jedna kilowatthodin včetně této režie. Nejde o naměřenou spotřebu tohoto typu stroje.

S publikovanými faktory Googlu za rok 2025 vychází v našem modelu přibližně dvanáct kilogramů ekvivalentu CO₂ pro Paříž, čtyři sta třicet osm pro Salt Lake City a čtyři sta devadesát čtyři pro Johannesburg. Mezi nejnižším a nejvyšším příkladem na tomto slidu je tedy přibližně čtyřicetinásobný rozdíl.

Jsou to roční průměry místních elektrických sítí. Mají jiný účel než hodinový průběh britské sítě, předpověď pro plánování úloh nebo vykázaná uhlíková stopa zákazníka cloudu. Model nezahrnuje výrobu hardwaru, úložiště ani síť.

Při rozhodování musíme zohlednit také latenci, dostupnou kapacitu a požadavky na umístění dat. V rámci těchto omezení může být volba regionu významnou částí výpočtu.

Tím máme pohromadě hlavní závěry dnešní přednášky.

## 17 — Key takeaways

Odnášíme si čtyři body.

Zaprvé, i malé edge zařízení můžeme zapojit do známého způsobu správy Kubernetes. k0s na edge, Argo CD v HQ a sdílený Prometheus tvoří použitelný vzor pro správu více lokalit.

Zadruhé, příkon a spotřeba energie mohou být součástí observability. Kepler pomáhá přiřadit spotřebu workloadům. Aby nám metriky pomohly, musíme vysvětlit rozsah měření, způsob přiřazení a případné odhady a propojit je s dokončenou prací.

Zatřetí, u flexibilních workloadů můžeme rozhodovat také o tom, kdy a kde poběží, při zachování termínu a požadované úrovně služby.

Začtvrté, kontrolujte uhlíkovou intenzitu cloudového regionu už při nasazení. V našem modelovém srovnání se stejnou energií vyšel mezi dvěma regiony přibližně čtyřicetinásobný rozdíl v provozních emisích.

Hardware ukazuje reakci na dostupnost obnovitelné energie. Skutečnou úsporu emisí bychom ověřovali pomocí vhodného uhlíkového signálu a porovnání stejné užitečné práce před změnou a po ní.

Jak s tím začít tento týden?

## 18 — Try it this week

Začněte jedním podporovaným uzlem a jedním workloadem. Ověřte, které energetické senzory máte k dispozici a co na dané sestavě Kepler skutečně exportuje.

Příkaz na slidu ukazuje současný upstream postup instalace. Naše demo na Raspberry používá starší chart společně s odpovídajícím dashboardem. Proto si pohlídejte, aby metriky a dokumentace odpovídaly nasazené verzi. Po ověření připněte konkrétní verzi chartu i obrazu.

Vyberte workload s měřitelným výstupem a určitou volností v plánování. Zaznamenejte spotřebu energie, dokončenou práci, dobu běhu a splnění požadavků na službu.

Pak změňte jednu věc: třeba dobu spuštění nebo vhodný region. Zopakujte stejnou práci a porovnejte výsledek, včetně dodatečných přenosů dat, restartů nebo režie čekání.

Pokud chcete snížit i základní spotřebu uzlu, ověřte, jestli infrastruktura dokáže workloady konsolidovat a nepotřebné stroje vypnout.

Jeden opakovatelný výsledek před změnou a po ní vám dá podklad pro rozhodnutí, co zkoušet dál.

## 19 — Thank you

Pokud si z dneška odnesete jednu myšlenku, ať je to tato: měřte energii potřebnou pro užitečnou práci a potom využijte volnost, kterou máte v tom, kdy a kde poběží.

QR kód vede do repozitáře s demem a prezentací. Jsou tam i předpoklady výpočtů a zdroje, takže si je můžete projít nebo experiment přizpůsobit.

Děkujeme, že jste přišli. Rádi uslyšíme, na jakém workloadu byste to zkusili vy a jaká omezení byste potřebovali dodržet.

A pokud se chcete podívat na hardware zblízka, přijďte si ten vánek vyzkoušet na vlastní kůži.

[Prostor pro otázky. Konec hlavní přednášky; na slide 20 pokračuj jen v případě potřeby.]

## 20 — Backup video

[Volitelné. Použij pouze při přechodu na záznam během dema. Potom se vrať k vysvětlení na slidu 14 nebo pokračuj otázkou pro publikum na slidu 15.]

Máme připravený záznam stejné sestavy, takže můžeme ukázat chování, o kterém chceme mluvit. Sledujte v něm propojení mezi měnícím se vstupním signálem, rozhodnutím o škálování a fyzickým zařízením.
