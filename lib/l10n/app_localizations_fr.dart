// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get daily => 'Quotidien';

  @override
  String get monthly => 'Mensuel';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get filters => 'Filtres';

  @override
  String get viewDensity => 'Densité d\'affichage';

  @override
  String get manageColumns => 'Gérer les colonnes';

  @override
  String get analytics => 'Statistiques';

  @override
  String get more => 'Plus';

  @override
  String get account => 'Compte';

  @override
  String get changeNameTitle => 'Changer de nom ?';

  @override
  String get changeNameBody => 'Vous serez déconnecté localement. Vos données restent sur le serveur sous votre nom actuel et peuvent être récupérées en saisissant exactement le même nom.';

  @override
  String get continueBtn => 'Continuer';

  @override
  String get signOutChange => 'Se déconnecter / changer de nom';

  @override
  String signedInAs(String email) {
    return 'Connecté en tant que « $email »';
  }

  @override
  String signedInAsChange(String email) {
    return 'Connecté en tant que « $email » — changer de nom';
  }

  @override
  String get tapToChangeName => 'Touchez pour changer de nom';

  @override
  String get reloadCloud => 'Recharger depuis le cloud';

  @override
  String get suggestIdea => 'Proposer une idée';

  @override
  String get add => 'Ajouter';

  @override
  String get cancel => 'Annuler';

  @override
  String get addTask => 'Ajouter une tâche';

  @override
  String get close => 'Fermer';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get rename => 'Renommer';

  @override
  String get retry => 'Réessayer';

  @override
  String get create => 'Créer';

  @override
  String get showAll => 'Tout afficher';

  @override
  String get hideAll => 'Tout masquer';

  @override
  String get untitledLower => 'sans titre';

  @override
  String get untitledCap => 'Sans titre';

  @override
  String get taskFallback => 'Tâche';

  @override
  String get rowsLbl => 'Lignes';

  @override
  String get daysLbl => 'Jours';

  @override
  String get typeLbl => 'Type';

  @override
  String get prevBtn => 'Préc.';

  @override
  String get nextBtn => 'Suiv.';

  @override
  String get upNext => 'À faire ensuite';

  @override
  String get editTip => 'Modifier';

  @override
  String get deleteTip => 'Supprimer';

  @override
  String get clearTip => 'Effacer';

  @override
  String get searchLbl => 'Rechercher';

  @override
  String get tasksHeader => 'Tâches';

  @override
  String get prevDaysTip => 'Jours précédents';

  @override
  String get nextDaysTip => 'Jours suivants';

  @override
  String rowsRange(String from, String to, String total) {
    return 'Lignes $from–$to sur $total';
  }

  @override
  String showingTip(String shown, String all, String daysPart) {
    return '$shown tâches sur $all affichées$daysPart — réglez dans les paramètres (icône curseurs). La colonne Tâches reste fixe pendant le défilement horizontal.';
  }

  @override
  String daysVisiblePart(String shown, String total) {
    return ' · $shown jours sur $total visibles';
  }

  @override
  String openDaily(String date) {
    return 'Ouvrir le $date en vue Quotidien';
  }

  @override
  String get addTaskTitle => 'Ajouter une tâche';

  @override
  String get taskNameLbl => 'Nom de la tâche';

  @override
  String get syncMonthlyTip => 'Synchroniser le mois vers Google';

  @override
  String syncedMsg(String count) {
    return '$count événements synchronisés vers Google Agenda';
  }

  @override
  String syncFailedMsg(String error) {
    return 'Échec de synchronisation : $error. Connectez Google d\'abord dans les paramètres (icône curseurs).';
  }

  @override
  String scheduledOf(String done, String total) {
    return '$done/$total planifiées';
  }

  @override
  String get todayChecklist => 'Aujourd\'hui (liste Android)';

  @override
  String get taskNameReq => 'Nom de la tâche *';

  @override
  String get taskNameHint => 'p. ex. Sport';

  @override
  String get scheduledDay => 'Jour planifié :';

  @override
  String get addDaysLbl => 'Jours (facultatif)';

  @override
  String get addDaysHint => 'Le nom seul est requis — laissez vide pour créer une tâche non planifiée.';

  @override
  String get scheduleLbl => 'Horaire';

  @override
  String get setTimeBtn => 'Définir l\'heure';

  @override
  String get timeDurationLbl => 'Durée';

  @override
  String get timeHint => 'p. ex. 3h5min, 4h, 30min';

  @override
  String get statusLbl => 'Statut';

  @override
  String get noteLbl => 'Note';

  @override
  String get noteHint => 'Ajoutez une note pour cette tâche…';

  @override
  String get createsHint => 'Crée la tâche et la planifie pour le jour choisi (case cochée = planifiée).';

  @override
  String statsFor(String day) {
    return 'Stats pour $day';
  }

  @override
  String get totalChip => 'Total';

  @override
  String tasksCount(String n) {
    return '$n tâches';
  }

  @override
  String get doneChip => 'Terminées';

  @override
  String get progChip => 'En cours';

  @override
  String get totalTimeChip => 'Temps total';

  @override
  String get doneTimeChip => 'Temps terminé';

  @override
  String get leftChip => 'Restant';

  @override
  String get elapsedChip => 'Écoulé';

  @override
  String pctDone(String pct) {
    return '$pct % terminé';
  }

  @override
  String get doneSection => 'Terminées';

  @override
  String moreSuffix(String n) {
    return '+$n de plus';
  }

  @override
  String get leftToDo => 'Reste à faire';

  @override
  String get noScheduled => 'Aucune tâche planifiée ce jour.';

  @override
  String get goWeeklyHint => 'Allez en vue Hebdomadaire et cochez les tâches voulues pour cette date.';

  @override
  String scheduledLine(String a, String b, String day) {
    return '$a tâches sur $b planifiées pour $day';
  }

  @override
  String rowsScheduled(String from, String to, String total) {
    return 'Lignes $from–$to sur $total planifiées';
  }

  @override
  String get manageColsTitle => 'Gérer les colonnes';

  @override
  String get introText => 'Ajoutez, renommez, supprimez, réordonnez et changez le type. Changer le type conserve la colonne mais efface ou convertit les valeurs existantes (au mieux).';

  @override
  String get hiddenBadge => 'masquée';

  @override
  String get showCol => 'Afficher la colonne';

  @override
  String get hideCol => 'Masquer la colonne';

  @override
  String get editTypeItem => 'Modifier / Changer le type';

  @override
  String typeChangedWarn(String from, String to) {
    return 'Le type passera de $from à $to. Les valeurs existantes seront effacées ou converties au mieux.';
  }

  @override
  String get insertPosition => 'Position d\'insertion';

  @override
  String get insertHelp => 'Choisissez où apparaît la nouvelle colonne. Valable pour tous les types.';

  @override
  String get anchorLbl => 'Colonne de référence';

  @override
  String get atBeginning => 'Au début (avant tout)';

  @override
  String get atEnd => 'À la fin (après tout)';

  @override
  String get beforeBtn => 'Avant';

  @override
  String get afterBtn => 'Après';

  @override
  String willInsert(String pos, String total) {
    return 'Sera insérée en position $pos sur $total';
  }

  @override
  String get unitLbl => 'Unité (h, min, etc.)';

  @override
  String get unitHint => 'h';

  @override
  String get timerHelp => 'Durée : les cellules stockent une durée (p. ex. 4h) avec compte à rebours. Touchez pour définir la durée, puis utilisez le minuteur.';

  @override
  String get statusOptsLbl => 'Options de statut (libellé + couleur) :';

  @override
  String get addOptionLbl => 'Ajouter une option';

  @override
  String get labelFieldLbl => 'libellé';

  @override
  String get pickColorTitle => 'Choisir une couleur';

  @override
  String get deleteColTitle => 'Supprimer la colonne ?';

  @override
  String deleteColBody(String name) {
    return 'Supprimer « $name » ? Toutes les valeurs de cette colonne seront effacées.';
  }

  @override
  String get footerDragHelp => 'Glissez la poignée pour réordonner. Les colonnes apparaissent comme sous-colonnes par jour en vue Hebdomadaire. Les changements de type conservent l\'ID.';

  @override
  String get addColTitle => 'Ajouter une colonne';

  @override
  String get editColTitle => 'Modifier la colonne';

  @override
  String get changeTypeTitle => 'Changer le type de colonne ?';

  @override
  String changeTypeBody(String name, String from, String to) {
    return 'Changer « $name » de $from à $to ? Les valeurs existantes seront effacées ou converties.';
  }

  @override
  String get changeBtn => 'Changer';

  @override
  String get colNameLbl => 'Nom de la colonne';

  @override
  String get visibleCols => 'Colonnes visibles';

  @override
  String get visibleColsShort => 'Colonnes visibles :';

  @override
  String get showShort => 'Voir :';

  @override
  String get visibilityHelp => 'Touchez pour réduire/agrandir chaque champ du jour. Les colonnes masquées restent dans vos données mais ne s\'affichent pas en Hebdomadaire/Quotidien.';

  @override
  String get ctCheckbox => 'Case à cocher';

  @override
  String get ctCheckboxDesc => 'Case unique — fait / non fait';

  @override
  String get ctStatus => 'Statut';

  @override
  String get ctStatusDesc => 'Liste colorée (p. ex. aucun / terminé / annulé)';

  @override
  String get ctNumber => 'Nombre / Durée';

  @override
  String get ctNumberDesc => 'Nombre avec unité optionnelle (h, min)';

  @override
  String get ctDate => 'Date';

  @override
  String get ctDateDesc => 'Sélecteur de date';

  @override
  String get ctDatetime => 'Date et heure';

  @override
  String get ctDatetimeDesc => 'Sélecteur de date + heure';

  @override
  String get ctTags => 'Étiquettes';

  @override
  String get ctTagsDesc => 'Plusieurs étiquettes colorées par cellule';

  @override
  String get ctText => 'Texte';

  @override
  String get ctTextDesc => 'Notes libres';

  @override
  String get ctTimer => 'Sélecteur de durée';

  @override
  String get ctTimerDesc => 'Durée estimée + minuteur en direct';

  @override
  String get ctSchedule => 'Horaire';

  @override
  String get ctScheduleDesc => 'Heure du jour (p. ex. 9h00)';

  @override
  String get ctReminder => 'Rappel';

  @override
  String get ctReminderDesc => 'Message daté — e-mail + notification à l\'heure dite';

  @override
  String get remCellTitle => 'Rappel';

  @override
  String get remDateLbl => 'Jour';

  @override
  String get remTimeLbl => 'Heure';

  @override
  String get remMsgLbl => 'Message';

  @override
  String get remMsgHint => 'De quoi faut-il vous prévenir ?';

  @override
  String get remEmpty => 'Touchez pour programmer un rappel…';

  @override
  String get remClearBtn => 'Effacer';

  @override
  String get remSavedTip => 'Rappel enregistré — e-mail + notification programmés.';

  @override
  String get welcome => 'Bienvenue sur 4cus';

  @override
  String get emailContinue => 'Saisissez votre e-mail pour continuer. Nous créons votre espace instantanément — sans mot de passe.';

  @override
  String get whyWorks => 'Pourquoi 4cus marche';

  @override
  String get whyText => 'La motivation s\'estompe. Les plans écrits, non.';

  @override
  String get studyQuote => '« Une étude sur la fixation d\'objectifs (Université dominicaine, 2015) montre que ceux qui ont écrit un plan précis ont réussi dans 70 % des cas, contre 35 % — littéralement le double. »';

  @override
  String get studyRef => '— Gail Matthews, 2015';

  @override
  String get emailLbl => 'Adresse e-mail *';

  @override
  String get emailHint => 'p. ex. alex@exemple.com';

  @override
  String get vipLbl => 'Clé VIP (optionnel)';

  @override
  String get emailKeyNote => 'votre e-mail est votre seule clé vers vos données — retenez exactement comment vous l\'avez saisi';

  @override
  String get cloudNotConfigured => 'Le cloud N\'EST PAS configuré dans cette version — les données resteront UNIQUEMENT sur cet appareil.';

  @override
  String get worksLine => 'Fonctionne sur le web et Android. Vos données se synchronisent instantanément via Supabase — hors ligne, les modifications patientent et réessaient.';

  @override
  String get suggestLink => 'Une idée pour améliorer 4cus ? Dites-le-nous';

  @override
  String get errEmail => 'Veuillez saisir une adresse e-mail valide.';

  @override
  String get errVip => 'Clé VIP invalide';

  @override
  String get vipRequired => 'VIP requis';

  @override
  String get vipRequiredText => 'Saisissez votre clé VIP pour débloquer la synchro Google Agenda.';

  @override
  String get vipKeyLbl => 'Clé VIP';

  @override
  String get vipKeyHint => 'collez votre clé';

  @override
  String get unlockBtn => 'Débloquer';

  @override
  String get enterVipKey => 'Saisissez une clé VIP';

  @override
  String get vipSaved => 'Clé VIP enregistrée — synchro Google débloquée !';

  @override
  String invalidVipKey(String error) {
    return 'Clé VIP invalide : $error';
  }

  @override
  String get addLaterNote => 'Vous pourrez ajouter la clé VIP plus tard dans les paramètres. Sans elle, les options restent grisées.';

  @override
  String get cloudOkTip => 'Synchro cloud : connectée';

  @override
  String get cloudOfflineTip => 'Synchro cloud : hors ligne — données enregistrées affichées';

  @override
  String get demoTip => 'Mode démo : cloud non configuré — données sur cet appareil uniquement';

  @override
  String get syncErrorTip => 'Échec de la synchro cloud';

  @override
  String get connectingTip => 'Connexion au cloud…';

  @override
  String get reloadTapHint => 'Touchez pour recharger depuis le cloud.';

  @override
  String signedInWord(String email) {
    return 'Connecté en tant que $email.';
  }

  @override
  String get demoBanner => 'Mode démo — le cloud n\'est pas configuré dans cette version, les données restent UNIQUEMENT sur cet appareil.';

  @override
  String recapTitle(String name) {
    return '$name — récap des notes';
  }

  @override
  String get notesRecap => 'Récap des notes';

  @override
  String notesRecapCount(String n) {
    return 'Récap des notes ($n)';
  }

  @override
  String get noNoteCol => 'Pas encore de colonne de notes — ajoutez-en une dans Gérer les colonnes.';

  @override
  String noNotesYet(String name, String col) {
    return 'Pas encore de notes pour « $name ». Ajoutez-en depuis n\'importe quelle cellule sous « $col ».';
  }

  @override
  String get tapOpenStudio => 'Touchez pour ouvrir dans le studio';

  @override
  String get reminderTitle => 'Rappel';

  @override
  String get reminderHint => 'p. ex. 10MI, 2H, 1D, 1W, 1M — vide = effacer';

  @override
  String get reminderUnitsHelp => 'MI = minutes · H = heures · D = jours · W = semaines · M = mois. Notifie avant la prochaine occurrence de la tâche.';

  @override
  String get reminderInvalid => 'Utilisez un nombre suivi de MI, H, D, W ou M (p. ex. 3D).';

  @override
  String reminderSet(String r) {
    return 'Rappel ($r)';
  }

  @override
  String get setReminderItem => 'Définir un rappel';

  @override
  String bellTip(String r) {
    return 'Rappel : $r';
  }

  @override
  String get openTooltip => 'Ouvrir';

  @override
  String get tabEdit => 'Modifier';

  @override
  String get tabPreview => 'Aperçu';

  @override
  String get writeHint => 'Écrivez votre note…';

  @override
  String get previewEmpty => 'Rien à prévisualiser pour l\'instant.';

  @override
  String autosavedAt(String time) {
    return 'Enregistré à $time';
  }

  @override
  String get savingNow => 'Enregistrement…';

  @override
  String get autosavesHint => 'Enregistrement auto pendant la frappe';

  @override
  String get writeNoteEmpty => 'Touchez pour écrire une note…';

  @override
  String editColLabel(String label) {
    return 'Modifier $label';
  }

  @override
  String get shapeTitle => 'Façonnez 4cus avec nous';

  @override
  String get shapeMsg => 'La personne moyenne n\'échoue pas par manque d\'ambition — elle échoue par manque de planification et de structure. C\'est pourquoi la plupart des objectifs s\'estompent et les plans s\'oublient.\n\n4cus existe pour changer cela, et nous le construisons en public. Votre suggestion façonne directement la suite — merci de nous aider à le construire avec vous.';

  @override
  String get nameEmailLbl => 'Votre nom ou e-mail';

  @override
  String get suggLbl => 'Votre suggestion…';

  @override
  String get suggHint => 'Qu\'est-ce qui rendrait 4cus meilleur pour vous ?';

  @override
  String get sendBtn => 'Envoyer';

  @override
  String get thankTitle => 'Merci !';

  @override
  String get thanksText => 'Votre suggestion a bien été reçue. Nous lisons chacune d\'elles, et les meilleures idées rejoignent la feuille de route.';

  @override
  String get errWriteFirst => 'Veuillez d\'abord écrire votre suggestion.';

  @override
  String get errNoCloud => 'Le cloud n\'est pas configuré dans cette version.';

  @override
  String get analyticsTitle => 'Statistiques';

  @override
  String get analyticsSubtitle => 'Vos progrès en un coup d\'œil';

  @override
  String get scheduledChip => 'Planifiées';

  @override
  String get doneChipA => 'Terminées';

  @override
  String get timePlanned => 'Temps prévu';

  @override
  String get timeDone => 'Temps terminé';

  @override
  String get weeklyProgress => 'Progrès hebdo (8 dernières semaines)';

  @override
  String get statusBreakdown => 'Répartition des statuts';

  @override
  String get timePerTask => 'Temps par tâche';

  @override
  String get completionPerTask => 'Achèvement par tâche';

  @override
  String get noTasksYet => 'Pas encore de tâches';

  @override
  String get plannedLeg => 'planifiées';

  @override
  String get progLeg => 'en cours';

  @override
  String get cancelLeg => 'annulées';

  @override
  String get doneLeg => 'terminées';

  @override
  String slotsDays(String slots, String days) {
    return '$slots créneaux · $days jours';
  }

  @override
  String get searchTasks => 'Rechercher des tâches';

  @override
  String get searchHint => 'Rechercher des tâches…';

  @override
  String get statusFilterLbl => 'Statut';

  @override
  String get allStatuses => 'Tous les statuts';

  @override
  String get tagFilterLbl => 'Étiquette';

  @override
  String get allTags => 'Toutes les étiquettes';

  @override
  String get hasNoteChip => 'Avec note';

  @override
  String get hasNoteOnlyChip => 'Avec note uniquement';

  @override
  String get clearFiltersBtn => 'Effacer';

  @override
  String get clearAllFilters => 'Effacer tous les filtres';

  @override
  String filtersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filtres actifs',
      one: '$count filtre actif',
    );
    return '$_temp0';
  }

  @override
  String activeShort(String count) {
    return '$count actifs';
  }

  @override
  String filtersFooter(String count) {
    return '$count actifs • Les filtres s\'appliquent aux vues Hebdo, Quotidien et Mensuel';
  }

  @override
  String tapFilterHint(String a, String b) {
    return '$a tâches sur $b • touchez l\'icône filtre pour plus';
  }

  @override
  String get todayTitle => 'Aujourd\'hui';

  @override
  String ofTasksHint(String a, String b) {
    return '$a tâches sur $b';
  }

  @override
  String get androidNote => 'Vue Android simplifiée — cases et statuts uniquement. Modifications structurelles sur le Web. Synchro temps réel via Supabase. File d\'attente hors ligne activée.';

  @override
  String get editsHint => 'Les modifications s\'enregistrent aussitôt et mettent à jour la carte mensuelle.';

  @override
  String get noScheduledTitle => 'Aucune tâche planifiée ce jour.';

  @override
  String get checkHint => 'Cochez la case d\'une tâche en vue Hebdomadaire ou Quotidienne pour la planifier à cette date.';

  @override
  String noneScheduledLine(String day, String total) {
    return '$day — $total tâches au total, aucune planifiée.';
  }

  @override
  String get checkScheduledHint => 'Cochez la case d\'une tâche en vue Hebdomadaire ou Quotidienne pour la planifier à cette date.';

  @override
  String get timerTitle => 'Minuteur';

  @override
  String get editDurationTip => 'Modifier la durée';

  @override
  String get editDurationTitle => 'Modifier la durée';

  @override
  String get durationLbl => 'Durée';

  @override
  String get setDurationBtn => 'Définir la durée';

  @override
  String get durationExample => 'p. ex. 4h, 30min, 1h 20m';

  @override
  String get remainingLbl => 'restant';

  @override
  String get completedLbl => 'terminé';

  @override
  String get pausedLbl => 'en pause';

  @override
  String elapsedOf(String eff, String total) {
    return '$eff écoulées / $total au total';
  }

  @override
  String get startBtn => 'Démarrer';

  @override
  String get resumeBtn => 'Reprendre';

  @override
  String get pauseBtn => 'Pause';

  @override
  String get stopBtn => 'Stop';

  @override
  String get restartBtn => 'Recommencer';

  @override
  String get completedBadge => 'Terminé';

  @override
  String get tagsTitle => 'Étiquettes';

  @override
  String get okBtn => 'OK';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifHelp => 'Alertes de minuteur, tâches du jour et rappels — sur Android et le web (onglet ouvert).';

  @override
  String get timerDoneTitle => 'Minuteur terminé';

  @override
  String get timerDoneSub => 'Quand un compte à rebours se termine';

  @override
  String get dailyBriefTitle => 'Résumé du jour';

  @override
  String get dailyBriefSub => 'Envoie les prochaines tâches du jour';

  @override
  String get sendTestNow => 'Envoyer un test';

  @override
  String atDaily(String time) {
    return 'à $time chaque jour';
  }

  @override
  String get timerRemTitle => 'Rappels de minuteur';

  @override
  String get timerRemSub => 'Avant la fin d\'un minuteur';

  @override
  String minSuffix(String m) {
    return '$m min';
  }

  @override
  String get noTasksToday => 'Aucune tâche prévue aujourd\'hui — touchez pour ouvrir 4cus.';

  @override
  String get tapToSee => 'Touchez pour voir le programme du jour';

  @override
  String get gcalTitle => 'Synchro Google Agenda';

  @override
  String get gcalHelp => 'Synchronisez la vue mensuelle vers votre Google Agenda automatiquement. Indiquez votre e-mail Google, acceptez l\'écran de consentement, et c\'est tout.';

  @override
  String get connectBtn => 'Connecter Google Agenda';

  @override
  String get connectHelp => 'Il vous sera demandé de choisir votre compte Google et d\'accepter l\'accès à l\'agenda.';

  @override
  String get disconnectBtn => 'Déconnecter';

  @override
  String get autoSyncLbl => 'Synchro auto mensuelle';

  @override
  String get autoSyncHelp => 'Activée, chaque changement de case / planification / durée crée ou met à jour un événement Google en quelques secondes.';

  @override
  String connectFailed(String error) {
    return 'Échec de connexion : $error';
  }

  @override
  String connectedAs(String email) {
    return 'Connecté en tant que $email';
  }

  @override
  String get rowsVisibleLbl => 'Lignes visibles à la fois';

  @override
  String get allRowsItem => 'Toutes les lignes';

  @override
  String rowsCountItem(String n) {
    return '$n lignes';
  }

  @override
  String get daysVisibleLbl => 'Colonnes-jours visibles (Hebdo)';

  @override
  String get allDaysItem => 'Tout (7 jours)';

  @override
  String daysCountItem(String n) {
    return '$n jours';
  }

  @override
  String get cellStyleLbl => 'Style de cellule (minuteur et statut)';

  @override
  String get fullBtn => 'Complet';

  @override
  String get basicBtn => 'Basique';

  @override
  String get basicHelp => 'Basique affiche minuteur/statut en icônes — touchez pour ouvrir l\'éditeur complet.';

  @override
  String get appearanceLbl => 'Apparence';

  @override
  String get darkBtn => 'Sombre';

  @override
  String get lightBtn => 'Clair';

  @override
  String get columnVisibilityHelp => 'La visibilité est enregistrée par utilisateur. Masquez horaire/durée/statut/note pour vous concentrer — p. ex. statut seul.';

  @override
  String get switchDark => 'Passer en mode sombre';

  @override
  String get switchLight => 'Passer en mode clair';

  @override
  String get changeNameQ => 'Changer de nom ?';

  @override
  String get changeNameQBody => 'Vos données restent sous le nom actuel. Vous pourrez les récupérer plus tard en saisissant exactement le même nom.';
}
