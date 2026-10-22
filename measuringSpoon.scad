// ---------------------------------------------------------------------------
// Parametric measuring spoon for an exact volume.
//
// The volume is the bowl interior filled exactly to the rim plane, modelled as
// a half-ellipsoid:   V = (2/3) * PI * r^2 * d
//
//   volumeMode = "grams" : volume [cm3] = gramsPerSpoon / density [g/cm3]
//   volumeMode = "volume": volume [cm3] = volumeCm3
//
// Examples
//   5 g of water        : volumeMode = "grams", density = 1.0,  gramsPerSpoon = 5
//   5 g of sugar        : volumeMode = "grams", density = 0.85, gramsPerSpoon = 5
//   1 cm3 (= 1 ml) spoon: volumeMode = "volume", volumeCm3 = 1
//
// Label: showLabel = "none" | "cut" | "colored".
//   cut     : the text is engraved into the handle (body colour).
//   colored : the text is engraved, then the groove is filled flush with a
//             solid in textColor. The inlay extends into the body and sits a
//             few microns below the surface so it fuses and does not z-fight
//             (labelOverlap / labelRecess).
// The label is on the handle face that is level with the rim, so in the
// recommended bowl-down print orientation it is printed face-down in the
// first layers and reads correctly once the spoon is turned bowl-up.
// spoonColor sets the body colour. Colours affect the preview/multi-material
// setup only; an STL export has no colour.
//
// The amount is level to the rim (heaping is not modelled). Print with the
// bowl opening DOWN: the STL is exported bowl-up, so flip it in the slicer
// and lay the rim lip and handle on the build plate. The outer dome then
// grows upward and the handle is not a cantilever. No supports are needed for
// the handle or rim; the only overhang is the bowl's inside ceiling, which is
// gradual and normally prints unsupported (add supports inside the bowl for
// very wide, shallow bowls or if the ceiling sags).
// ---------------------------------------------------------------------------

/* [Volume] */
volumeMode        = "grams"; // [volume:Volume, grams:Grams]
density           = 1.0;   // g/cm3 (water 1.0, sugar 0.85, salt 1.2, flour 0.55)
gramsPerSpoon     = 5;     // target grams per spoon
volumeCm3         = 1;     // target volume in cm3 (e.g. 1 for a 1 cm3 spoon)

/* [Bowl] */
bowlMode      = "auto"; // [auto:Proportional, fixed:Fixed diameter]
depthRatio    = 0.5;    // depth / radius (Proportional mode)
bowlDiameter  = 25;     // mm, rim diameter (Fixed diameter mode only)
wallThickness = 1.6;    // mm
rimLip        = 1.2;    // mm flat rim lip, flush with the fill line

/* [Handle] */
handleLength    = 45;   // mm, rim to the centre of the rounded end
handleWidth     = 11;   // mm at the bowl
handleTipWidth  = 9;    // mm at the rounded end
handleThickness = 3;    // mm
handleHole      = true; // hanging hole
handleHoleDia   = 4;    // mm

/* [Label] */
showLabel  = "cut"; // [none:No label, cut:Cut/engraved, colored:Colored inlay]
labelText  = "";    // blank = automatic ("5 g" or "1 ml")
labelSize  = 5;     // mm
labelDepth = 0.4;   // mm, cut depth (= inlay depth)
labelOverlap = 0.05;  // mm, coloured inlay extends into the body so it fuses
labelRecess  = 0.005; // mm, coloured inlay top sits just below the surface
labelFont  = "Liberation Sans:style=Bold";

/* [Color] */
// Pick from the predefined colour lists.
spoonColor = "white";  // [white:White, ivory:Ivory, silver:Silver, gray:Gray, black:Black, red:Red, orange:Orange, gold:Gold, yellow:Yellow, lime:Lime, green:Green, olive:Olive, teal:Teal, aqua:Aqua, blue:Blue, navy:Navy, purple:Purple, violet:Violet, pink:Pink, brown:Brown]
textColor  = "black";  // [white:White, ivory:Ivory, silver:Silver, gray:Gray, black:Black, red:Red, orange:Orange, gold:Gold, yellow:Yellow, lime:Lime, green:Green, olive:Olive, teal:Teal, aqua:Aqua, blue:Blue, navy:Navy, purple:Purple, violet:Violet, pink:Pink, brown:Brown]

/* [Hidden] */
lipThickness = 1.0;
// In preview only ($preview), nudge the lip and handle top just below the rim
// plane so they are not coplanar with it. That is what makes OpenCSG preview
// flicker. During a full render (F6) both offsets are 0, so the exported
// geometry stays exactly flush. Different offsets keep the two faces from
// becoming coplanar with each other.
previewDrop = $preview ? 0.00005 : 0;
handleDrop  = $preview ? 0.00010 : 0;
debugInterior      = false; // render the exact cavity as a solid (verify volume)
compensateFaceting = true;  // pre-inflate for polygon faceting so the mesh matches
volumeCorrection   = 1.0;   // extra trim for real prints; 1.0 = ideal geometry
$fn = 128;

// ---------------------------------------------------------------------------
// Derived values
// ---------------------------------------------------------------------------

// Faceting of the curved cavity makes the exported mesh slightly smaller than
// the analytic ellipsoid. For OpenSCAD's sphere tessellation the mesh volume is
// (1 - 16.45 / $fn^2) of the analytic volume, so divide it out to make the
// modelled cavity match the target (disable with compensateFaceting = false).
function facetFactor() =
    (compensateFaceting && $fn > 0) ? 1 - 16.45 / ($fn * $fn) : 1;

// Volume the spoon should hold, in mm3, as entered in the configurator.
function requestedVolumeMm3() =
    volumeCorrection * (volumeMode == "volume"
        ? volumeCm3 * 1000
        : gramsPerSpoon / density * 1000);

// Analytic cavity volume drawn by the model. Inflated by the inverse faceting
// factor so the exported polygon mesh holds requestedVolumeMm3().
function targetVolumeMm3() =
    requestedVolumeMm3() / facetFactor();

// Rim radius of the bowl interior.
//   Proportional : fix d = depthRatio * r -> r = cbrt(3V / (2*PI*depthRatio))
//   Fixed diameter: r = bowlDiameter / 2
function bowlRadius() =
    bowlMode == "fixed"
        ? bowlDiameter / 2
        : pow(3 * targetVolumeMm3() / (2 * PI * depthRatio), 1 / 3);

// Bowl interior depth.
//   Proportional  : d = depthRatio * r
//   Fixed diameter: d = 3V / (2*PI*r^2)
function bowlDepth() =
    bowlMode == "fixed"
        ? 3 * targetVolumeMm3() / (2 * PI * pow(bowlRadius(), 2))
        : depthRatio * bowlRadius();

r = bowlRadius();
d = bowlDepth();
R = r + wallThickness;
xTip = R + handleLength;
xHole = xTip;                 // hanging hole centred in the rounded end
xLabel = R + handleLength * 0.45;
handleTopZ = -handleDrop;     // 0 in a full render, slightly sunk in preview

// Keep the hanging hole clear of the bowl and leave a wall around the tip.
holeFits = (handleHoleDia / 2 + 1) < (handleTipWidth / 2)
        && (xHole - handleHoleDia / 2) > (R + 1);

labelString = labelText != ""
    ? labelText
    : (volumeMode == "volume" ? str(volumeCm3, " ml") : str(gramsPerSpoon, " g"));

assert(requestedVolumeMm3() > 0, "Target volume must be greater than 0");
assert(volumeMode == "volume" || volumeMode == "grams",
       "volumeMode must be 'volume' or 'grams'");
assert(volumeMode != "volume" || volumeCm3 > 0, "volumeCm3 must be greater than 0");
assert(density > 0, "density must be greater than 0");
assert(bowlMode == "fixed" ? bowlDiameter > 0 : depthRatio > 0,
       "bowlDiameter / depthRatio must be greater than 0");
assert(d > 0.5, "Computed bowl depth is too small; increase bowlDiameter or depthRatio");
assert(d < 200, "Computed bowl depth is unrealistically large; check the inputs");
assert(showLabel == "none" || showLabel == "cut" || showLabel == "colored",
       "showLabel must be 'none', 'cut' or 'colored'");
assert(labelOverlap >= 0 && labelRecess >= 0 && labelRecess < labelDepth,
       "labelOverlap must be >= 0 and labelRecess between 0 and labelDepth");

echo(str("Requested volume : ", requestedVolumeMm3() / 1000, " cm3 (", requestedVolumeMm3(), " mm3)"));
echo(str("Bowl radius      : ", r, " mm  (diameter ", 2 * r, " mm)"));
echo(str("Bowl depth       : ", d, " mm"));
echo(str("Faceting factor  : ", facetFactor(), " at $fn=", $fn, " (mesh matches requested volume)"));

if (handleHole && !holeFits)
    echo("WARNING: handle tip too small or too short for the hanging hole - hole skipped.");

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

// Lower half of an ellipsoid with horizontal semi-axes rx, rx and vertical
// semi-axis rz. The flat face sits on the rim plane z = 0.
module halfEllipsoid(rx, rz) {
    intersection() {
        scale([rx, rx, rz]) sphere(r = 1);
        translate([-rx * 1.3, -rx * 1.3, -rz * 1.3])
            cube([rx * 2.6, rx * 2.6, rz * 1.3]);
    }
}

// Full ellipsoid. Used for the cavity cut: a full ellipsoid crosses the rim
// plane with a clean edge instead of a coplanar cap, which avoids the
// OpenCSG preview artefact where the opening appears covered/flickering.
module fullEllipsoid(rx, rz) {
    scale([rx, rx, rz]) sphere(r = 1);
}

// Flat rim lip. Its top face sits just below z = 0 (previewDrop) so it is not
// coplanar with the rim plane; it still does not add any cavity volume.
module rimRing() {
    if (rimLip > 0.01) {
        translate([0, 0, -lipThickness - previewDrop])
            difference() {
                cylinder(h = lipThickness, r = R + rimLip);
                translate([0, 0, -0.1])
                    cylinder(h = lipThickness + 0.2, r = R - 0.1);
            }
    }
}

// Bowl shell: outer half-ellipsoid minus the exact inner ellipsoid. The inner
// cut is a FULL ellipsoid so it crosses the rim plane instead of leaving a
// coplanar cap (which makes the preview look closed). The upper half is above
// the body and removes nothing, so the cavity volume is unchanged.
module bowl() {
    difference() {
        union() {
            halfEllipsoid(R, d + wallThickness);
            rimRing();
        }
        fullEllipsoid(r, d);
    }
}

// Handle profile. The flat root edge starts at x = r (the cavity wall), so the
// handle never intrudes into the bowl volume and is embedded in the wall.
module handleProfile() {
    hull() {
        translate([r, -handleWidth / 2])
            square([6, handleWidth]);
        translate([xTip, 0])
            circle(d = handleTipWidth);
    }
}

module handleSolid() {
    // Top face sits handleDrop below the rim in preview to avoid z-fighting.
    translate([0, 0, -handleThickness])
        linear_extrude(height = handleThickness - handleDrop)
            handleProfile();
}

module handleHoleCut() {
    if (handleHole && holeFits) {
        translate([xHole, 0, -handleThickness - 0.5])
            cylinder(h = handleThickness + 1, d = handleHoleDia);
    }
}

// Engraved label: cut into the handle top.
module labelCut() {
    translate([xLabel, 0, handleTopZ - labelDepth])
        linear_extrude(height = labelDepth + handleDrop + 0.1)
            text(labelString,
                 size = labelSize,
                 halign = "center",
                 valign = "center",
                 font = labelFont);
}

// Coloured inlay: fills the cut groove. It is slightly wider than the groove
// and extends below its floor so it fuses into the body, and its top sits
// labelRecess below the surface (effectively flush) so the body top wins the
// depth test instead of z-fighting.
module labelInfill() {
    translate([xLabel, 0, handleTopZ - labelDepth - labelOverlap])
        linear_extrude(height = labelDepth + labelOverlap - labelRecess)
            offset(delta = labelOverlap)
                text(labelString,
                     size = labelSize,
                     halign = "center",
                     valign = "center",
                     font = labelFont);
}

module spoonBody() {
    difference() {
        union() {
            bowl();
            handleSolid();
        }
        handleHoleCut();
        if (showLabel != "none") labelCut();
    }
}

// ---------------------------------------------------------------------------

if (debugInterior) {
    // Solid plug of the exact cavity volume, for verification in a slicer.
    color("orange", 0.6) halfEllipsoid(r, d);
} else {
    color(spoonColor) spoonBody();
    if (showLabel == "colored") color(textColor) labelInfill();
}
