import React, { useState, useEffect, useRef } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Search as SearchIcon, Instagram, FlaskConical, BookOpen, HeartPulse, MessageCircle, Info, FileText, ChevronDown } from "lucide-react";
import SearchPanel from "./SearchPanel";
import NavMegaMenu from "./NavMegaMenu";
import ProfileMenu from "./ProfileMenu";
import { FEATURES } from "@/data/features";

const EXPLORE_ITEMS = [
  { icon: FlaskConical, title: "Research", desc: "Emerging science, translated", path: "/research" },
  { icon: BookOpen, title: "Condition Library", desc: "150+ chronic conditions", path: "/library" },
  { icon: HeartPulse, title: "The Apothecary", desc: "Recipes, rituals, wellness", path: "/health" },
  { icon: MessageCircle, title: "Community", desc: "Anonymous, moderated", path: "/community", memberOnly: true },
];

const ABOUT_ITEMS = [
  { icon: Info, title: "About VIDA LAB", desc: "Our mission and story", path: "/about" },
  { icon: FileText, title: "Rowan's Work", desc: "Research papers", path: "/rowans-work" },
];

const NAV_SECTIONS = [
  { key: "explore", label: "Explore" },
  { key: "features", label: "Features" },
  { key: "about", label: "About" },
];

export default function SiteHeader() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [activeMenu, setActiveMenu] = useState(null);
  const [touchStart, setTouchStart] = useState(null);

  const handleMenuTouchStart = (e) => {
    if (!menuOpen) return;
    setTouchStart({ x: e.touches[0].clientX, y: e.touches[0].clientY });
  };

  const handleMenuTouchMove = (e) => {
    if (!touchStart || !menuOpen) return;
    const dy = e.touches[0].clientY - touchStart.y;
    if (dy < 0) {
      const nav = e.currentTarget;
      nav.style.transform = `translateY(${dy}px)`;
      nav.style.opacity = `${Math.max(0.2, 1 + dy / 250)}`;
    }
  };

  const handleMenuTouchEnd = (e) => {
    if (!touchStart || !menuOpen) return;
    const end = e.changedTouches[0];
    const dx = end.clientX - touchStart.x;
    const dy = end.clientY - touchStart.y;
    const nav = e.currentTarget;
    nav.style.transform = "";
    nav.style.opacity = "";
    if (dy < -60 && Math.abs(dy) > Math.abs(dx)) {
      setMenuOpen(false);
    }
    setTouchStart(null);
  };
  const location = useLocation();
  const navigate = useNavigate();
  const { user } = useAuth();
  const closeTimeoutRef = useRef(null);
  const headerRef = useRef(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    window.addEventListener("scroll", onScroll);
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => { setMenuOpen(false); setActiveMenu(null); }, [location.pathname]);

  useEffect(() => {
    if (!menuOpen) return;
    const onClickOutside = (e) => {
      if (headerRef.current && !headerRef.current.contains(e.target)) {
        setMenuOpen(false);
      }
    };
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, [menuOpen]);

  const isActive = (path) => location.pathname === path;

  const handleLogout = async () => {
    await base44.auth.logout();
    navigate("/");
  };

  const featureItems = FEATURES.filter((f) => f.memberOnly || f.title === "Ask Vida").map((f) => ({
    icon: f.icon,
    title: f.title,
    desc: f.description,
    path: f.path,
    plus: f.plus,
    memberOnly: f.memberOnly,
  }));

  const MENUS = {
    explore: EXPLORE_ITEMS,
    features: featureItems,
    about: ABOUT_ITEMS,
  };

  const openMenu = (menu) => {
    clearTimeout(closeTimeoutRef.current);
    setActiveMenu(menu);
  };

  const scheduleClose = () => {
    clearTimeout(closeTimeoutRef.current);
    closeTimeoutRef.current = setTimeout(() => setActiveMenu(null), 200);
  };

  const cancelClose = () => {
    clearTimeout(closeTimeoutRef.current);
  };

  useEffect(() => () => clearTimeout(closeTimeoutRef.current), []);

  return (
    <>
      <header ref={headerRef} className={`site-header${scrolled ? " scrolled" : ""}`}>
        <div className="nav wrap">
          <Link className="brand" to="/">
            <img src="https://media.base44.com/images/public/6aacae7dbd22557932ef6597/16df04c2a_ChatGPTImageSep22202612_00_37AM.png" alt="VIDA LAB by Rowan Albritton" className="brand-wordmark" />
          </Link>
          <nav
            className={`nav-menu${menuOpen ? " open" : ""}`}
            aria-label="Main navigation"
            onTouchStart={handleMenuTouchStart}
            onTouchMove={handleMenuTouchMove}
            onTouchEnd={handleMenuTouchEnd}
          >
            <div className="nav-links">
              {/* Desktop: hover triggers for mega menu */}
              {NAV_SECTIONS.map((s) => (
                <button
                  key={s.key}
                  className={`nav-mega-trigger${activeMenu === s.key ? " active" : ""}`}
                  onMouseEnter={() => openMenu(s.key)}
                  onMouseLeave={scheduleClose}
                  onClick={() => setActiveMenu(activeMenu === s.key ? null : s.key)}
                >
                  {s.label}
                </button>
              ))}
              {/* Mobile: expandable sections */}
              {NAV_SECTIONS.map((s) => (
                <div key={`m-${s.key}`} className="nav-mobile-section">
                  <button
                    className="nav-mobile-trigger"
                    onClick={() => setActiveMenu(activeMenu === s.key ? null : s.key)}
                  >
                    {s.label} <ChevronDown size={14} strokeWidth={1.5} />
                  </button>
                  {activeMenu === s.key && (
                    <div className="nav-mobile-items">
                      {MENUS[s.key].map((item) => {
                        const linkPath = item.memberOnly && !user ? "/login" : item.path;
                        return (
                          <Link
                            key={item.title}
                            to={linkPath}
                            className="nav-mobile-item"
                            onClick={() => { setActiveMenu(null); setMenuOpen(false); }}
                          >
                            {item.title}
                            {item.plus && <span className="nav-mega-plus">+</span>}
                          </Link>
                        );
                      })}
                    </div>
                  )}
                </div>
              ))}
              <Link to="/rowans-work" className={isActive("/rowans-work") ? "active" : ""}>Rowan's Work</Link>
              <Link to="/vida-plus" className={isActive("/vida-plus") ? "active" : ""}>Vida+</Link>
            </div>
            <div className="nav-mobile-auth">
              <a className="search-button" aria-label="VIDA LAB on Instagram" href="https://www.instagram.com/thevidalab" target="_blank" rel="noopener noreferrer">
                <Instagram size={18} strokeWidth={1.5} />
              </a>
              {user ? (
                <button onClick={handleLogout} className="auth-button">Sign out</button>
              ) : (
                <Link to="/login" className="auth-button">Sign in</Link>
              )}
            </div>
          </nav>
          <div className="nav-actions">
            <a className="search-button" aria-label="VIDA LAB on Instagram" href="https://www.instagram.com/thevidalab" target="_blank" rel="noopener noreferrer">
              <Instagram size={18} strokeWidth={1.5} />
            </a>
            <button className="search-button" aria-label="Search" onClick={() => setSearchOpen(true)}>
              <SearchIcon size={18} strokeWidth={1.5} />
            </button>
            {user ? (
              <ProfileMenu />
            ) : (
              <Link to="/login" className="auth-button">Sign in</Link>
            )}
          </div>
          <div className="mobile-actions">
            <button className="search-button mobile-search-button" aria-label="Search" onClick={() => setSearchOpen(true)}>
              <SearchIcon size={20} strokeWidth={1.5} />
            </button>
            <button className="menu-button" aria-label="Open menu" aria-expanded={menuOpen} onClick={() => setMenuOpen(!menuOpen)}>
              Menu
            </button>
          </div>
        </div>
      </header>
      <NavMegaMenu
        activeMenu={activeMenu}
        menus={MENUS}
        user={user}
        onPanelEnter={cancelClose}
        onPanelLeave={scheduleClose}
        onNavigate={() => setActiveMenu(null)}
      />
      <SearchPanel open={searchOpen} onClose={() => setSearchOpen(false)} />
    </>
  );
}