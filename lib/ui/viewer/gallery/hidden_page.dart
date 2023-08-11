import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/db/files_db.dart';
import 'package:photos/events/files_updated_event.dart';
import "package:photos/generated/l10n.dart";
import "package:photos/models/collection.dart";
import 'package:photos/models/gallery_type.dart';
import "package:photos/models/metadata/common_keys.dart";
import 'package:photos/models/selected_files.dart';
import 'package:photos/services/collections_service.dart';
import "package:photos/services/filter/db_filters.dart";
import "package:photos/services/hidden_service.dart";
import "package:photos/ui/collections/album/horizontal_list.dart";
import "package:photos/ui/common/loading_widget.dart";
import 'package:photos/ui/viewer/actions/file_selection_overlay_bar.dart';
import 'package:photos/ui/viewer/gallery/empty_hidden_widget.dart';
import 'package:photos/ui/viewer/gallery/gallery.dart';
import 'package:photos/ui/viewer/gallery/gallery_app_bar_widget.dart';

class HiddenPage extends StatefulWidget {
  final String tagPrefix;
  final GalleryType appBarType;
  final GalleryType overlayType;

  const HiddenPage({
    this.tagPrefix = "hidden_page",
    this.appBarType = GalleryType.hidden,
    this.overlayType = GalleryType.hidden,
    Key? key,
  }) : super(key: key);

  @override
  State<HiddenPage> createState() => _HiddenPageState();
}

class _HiddenPageState extends State<HiddenPage> {
  Set<int>? _hiddenCollectionIds;
  int? _defaultHiddenCollectionId;
  final _selectedFiles = SelectedFiles();

  @override
  void initState() {
    super.initState();
    final allHiddenCollectionIDs =
        CollectionsService.instance.getHiddenCollections();

    CollectionsService.instance.getDefaultHiddenCollection().then((collection) {
      setState(() {
        _defaultHiddenCollectionId = collection.id;
        _hiddenCollectionIds =
            allHiddenCollectionIDs.difference({_defaultHiddenCollectionId});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hiddenCollectionIds == null) {
      return const EnteLoadingWidget();
    }
    final gallery = Gallery(
      asyncLoader: (creationStartTime, creationEndTime, {limit, asc}) {
        return FilesDB.instance.getAllPendingOrUploadedFiles(
          creationStartTime,
          creationEndTime,
          Configuration.instance.getUserID()!,
          visibility: hiddenVisibility,
          limit: limit,
          asc: asc,
          filterOptions: DBFilterOptions(
            hideIgnoredForUpload: true,
            dedupeUploadID: true,
            ignoredCollectionIDs: _hiddenCollectionIds,
          ),
          applyOwnerCheck: true,
        );
      },
      reloadEvent: Bus.instance.on<FilesUpdatedEvent>().where(
            (event) =>
                event.updatedFiles.firstWhereOrNull(
                  (element) => element.uploadedFileID != null,
                ) !=
                null,
          ),
      removalEventTypes: const {
        EventType.unhide,
        EventType.deletedFromEverywhere,
        EventType.deletedFromRemote
      },
      forceReloadEvents: [
        Bus.instance.on<FilesUpdatedEvent>().where(
              (event) =>
                  event.updatedFiles.firstWhereOrNull(
                    (element) => element.uploadedFileID != null,
                  ) !=
                  null,
            ),
      ],
      tagPrefix: widget.tagPrefix,
      selectedFiles: _selectedFiles,
      initialFiles: null,
      emptyState: const EmptyHiddenWidget(),
      header: AlbumHorizontalList(
        () async {
          final hiddenCollections = <Collection>[];
          for (int hiddenCollectionId in _hiddenCollectionIds!) {
            hiddenCollections.add(
              CollectionsService.instance
                  .getCollectionByID(hiddenCollectionId)!,
            );
          }
          return hiddenCollections;
        },
        hasVerifiedLock: true,
      ),
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0),
        child: GalleryAppBarWidget(
          widget.appBarType,
          S.of(context).hidden,
          _selectedFiles,
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          gallery,
          FileSelectionOverlayBar(
            widget.overlayType,
            _selectedFiles,
          ),
        ],
      ),
    );
  }
}
