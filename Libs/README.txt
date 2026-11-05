Bundled libraries (GatherTimes)
================================

These four files are loaded by GatherTimes.toc, in this order, before Core\Util.lua.
LibStub keeps the newest copy when another addon bundles the same library.

  LibStub\LibStub.lua
  CallbackHandler-1.0\CallbackHandler-1.0.lua
  HereBeDragons\HereBeDragons-2.0.lua
  HereBeDragons\HereBeDragons-Pins-2.0.lua

Without them the addon still runs when another addon provides HereBeDragons; otherwise it prints a
missing-library warning and the distance / route features stay off.

.pkgmeta (repo root) keeps these bundled copies. If you would rather have the packager fetch them,
uncomment the externals block in .pkgmeta and delete the files here.
