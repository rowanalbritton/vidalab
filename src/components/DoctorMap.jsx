import React, { useMemo } from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// US city → [lat, lng] coordinates
const CITY_COORDS = {
  // Florida — South
  Miami: [25.76, -80.19],
  "Coral Gables": [25.72, -80.27],
  "Pembroke Pines": [26.01, -80.23],
  "Cooper City": [26.06, -80.29],
  "Fort Lauderdale": [26.12, -80.14],
  "Coconut Creek": [26.27, -80.19],
  "Coral Springs": [26.27, -80.27],
  "Boca Raton": [26.37, -80.09],
  "West Palm Beach": [26.72, -80.05],
  "Palm Beach Gardens": [26.84, -80.14],
  "Lake Worth": [26.62, -80.07],
  Weston: [26.1, -80.33],
  // Florida — Southwest
  "Fort Myers": [26.64, -81.87],
  "Cape Coral": [26.56, -82.01],
  "Bonita Springs": [26.34, -81.78],
  Venice: [27.1, -82.46],
  Sarasota: [27.34, -82.54],
  Bradenton: [27.5, -82.57],
  // Florida — Tampa Bay
  Tampa: [27.95, -82.46],
  "St Petersburg": [27.77, -82.64],
  Clearwater: [27.97, -82.77],
  "Pinellas Park": [27.84, -82.71],
  "Palm Harbor": [28.11, -82.77],
  Trinity: [28.12, -82.67],
  Zephyrhills: [28.24, -82.18],
  Brooksville: [28.56, -82.49],
  // Florida — Central
  Orlando: [28.54, -81.38],
  "Winter Park": [28.6, -81.35],
  "Altamonte Springs": [28.66, -81.37],
  "Winter Garden": [28.47, -81.59],
  Sebring: [27.5, -81.44],
  // Florida — North
  Gainesville: [29.65, -82.32],
  Jacksonville: [30.33, -81.66],
  // Northeast
  "New York": [40.71, -74.01],
  Brooklyn: [40.68, -73.94],
  "White Plains": [41.03, -73.76],
  "New Hyde Park": [40.73, -73.69],
  "Garden City": [40.73, -73.67],
  Boston: [42.36, -71.06],
  Philadelphia: [39.95, -75.17],
  Harrisburg: [40.27, -76.88],
  Baltimore: [39.29, -76.61],
  Bethesda: [38.98, -77.1],
  Washington: [38.9, -77.04],
  // Midwest
  Chicago: [41.88, -87.63],
  Cleveland: [41.5, -81.69],
  Columbus: [39.96, -82.99],
  "St. Louis": [38.63, -90.2],
  "Overland Park": [38.98, -94.67],
  Rochester: [44.02, -92.47],
  // South
  Atlanta: [33.75, -84.39],
  "Peachtree City": [33.4, -84.59],
  Charlotte: [35.23, -80.84],
  "Oklahoma City": [35.47, -97.52],
  Dallas: [32.78, -96.8],
  Houston: [29.76, -95.37],
  Austin: [30.27, -97.74],
  // West
  Denver: [39.74, -104.99],
  Phoenix: [33.45, -112.07],
  Scottsdale: [33.49, -111.93],
  "Los Angeles": [34.05, -118.24],
  "Santa Monica": [34.02, -118.48],
  "San Francisco": [37.77, -122.42],
  "San Jose": [37.34, -121.89],
  Poway: [32.74, -117.04],
  Duarte: [34.14, -117.98],
  Portland: [45.52, -122.68],
  Seattle: [47.61, -122.33],
  Reno: [39.53, -119.81],
};

const CATEGORY_COLORS = {
  autoimmune: "#a8412b",
  neurological: "#2E463E",
  cardiovascular: "#c0392b",
  endocrine: "#7d3c98",
  musculoskeletal: "#d35400",
  gastrointestinal: "#27ae60",
  respiratory: "#2980b9",
  mental_health: "#8e44ad",
  chronic_pain: "#e74c3c",
  dysautonomia: "#16a085",
  gynecological: "#c2185b",
  other: "#7f8c8d",
};

function createIcon(count, color) {
  const size = count > 5 ? 36 : count > 1 ? 30 : 24;
  return L.divIcon({
    className: "doctor-map-marker",
    html: `<div style="
      width:${size}px;height:${size}px;
      background:${color};
      border:2px solid #F9F8F5;
      border-radius:50% 50% 50% 0;
      transform:rotate(-45deg);
      box-shadow:0 2px 8px rgba(0,0,0,.35);
      display:flex;align-items:center;justify-content:center;
      font-size:${count > 1 ? "11px" : "0"};font-weight:700;
      color:#F9F8F5;font-family:'DM Sans',sans-serif;
    "><span style="transform:rotate(45deg)">${count > 1 ? count : ""}</span></div>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size],
    popupAnchor: [0, -size + 4],
  });
}

export default function DoctorMap({ doctors }) {
  const cityGroups = useMemo(() => {
    const groups = {};
    doctors.forEach((d) => {
      const coords = CITY_COORDS[d.city];
      if (!coords) return;
      if (!groups[d.city]) groups[d.city] = { coords, doctors: [] };
      groups[d.city].doctors.push(d);
    });
    return groups;
  }, [doctors]);

  const mappableCount = useMemo(
    () => Object.values(cityGroups).reduce((sum, g) => sum + g.doctors.length, 0),
    [cityGroups]
  );

  if (mappableCount === 0) return null;

  return (
    <>
      <style>{`
        .doctor-map-wrap .leaflet-popup-content-wrapper{
          border-radius:16px;box-shadow:0 4px 20px rgba(0,0,0,.12);
          max-height:300px;overflow-y:auto;
        }
        .doctor-map-wrap .leaflet-popup-content{
          margin:14px 18px;font-family:'DM Sans',sans-serif;line-height:1.4;
        }
        .doctor-map-wrap .leaflet-popup-content .popup-city{
          font-family:'Newsreader',Georgia,serif;font-size:16px;
          color:#2E463E;font-weight:600;display:block;margin-bottom:8px;
        }
        .doctor-map-wrap .leaflet-popup-content .popup-doc{
          padding:7px 0;border-top:1px solid #E8E5DF;
        }
        .doctor-map-wrap .leaflet-popup-content .popup-doc:first-of-type{border-top:0}
        .doctor-map-wrap .leaflet-popup-content .popup-doc h4{
          font-family:'Newsreader',Georgia,serif;font-size:14px;
          color:#2E463E;margin:0 0 2px;font-weight:500;
        }
        .doctor-map-wrap .leaflet-popup-content .popup-doc p{
          font-size:11px;color:#5a655e;margin:0;
        }
        .doctor-map-wrap .leaflet-control-attribution{
          font-size:9px;background:rgba(255,255,255,.7);
        }
      `}</style>
      <div
        className="doctor-map-wrap"
        style={{
          height: "460px",
          borderRadius: "20px",
          overflow: "hidden",
          border: "1px solid #E8E5DF",
        }}
      >
        <MapContainer
          center={[39.0, -96.0]}
          zoom={4}
          style={{ height: "100%", width: "100%" }}
          scrollWheelZoom={false}
        >
          <TileLayer
            url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
            attribution='&copy; OpenStreetMap &copy; CARTO'
          />
          {Object.entries(cityGroups).map(([city, { coords, doctors: cityDocs }]) => {
            const cats = cityDocs.map((d) => d.category).filter(Boolean);
            const dominantCat = cats.sort(
              (a, b) => cats.filter((v) => v === b).length - cats.filter((v) => v === a).length
            )[0];
            const color = CATEGORY_COLORS[dominantCat] || "#2E463E";
            return (
              <Marker key={city} position={coords} icon={createIcon(cityDocs.length, color)}>
                <Popup>
                  <span className="popup-city">
                    {city} — {cityDocs.length} {cityDocs.length === 1 ? "doctor" : "doctors"}
                  </span>
                  {cityDocs.map((d) => (
                    <div key={d.id} className="popup-doc">
                      <h4>{d.practice_name}</h4>
                      <p>{d.specialty}</p>
                    </div>
                  ))}
                </Popup>
              </Marker>
            );
          })}
        </MapContainer>
      </div>
    </>
  );
}