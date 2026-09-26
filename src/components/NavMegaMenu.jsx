import React from "react";
import { Link } from "react-router-dom";
import { motion, AnimatePresence } from "framer-motion";

export default function NavMegaMenu({ activeMenu, menus, user, onPanelEnter, onPanelLeave, onNavigate }) {
  const items = activeMenu ? menus[activeMenu] : null;

  return (
    <AnimatePresence>
      {items && (
        <motion.div
          className="nav-mega-panel"
          initial={{ opacity: 0, y: -16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -16 }}
          transition={{ duration: 0.35, ease: [0.25, 0.1, 0.25, 1] }}
          onMouseEnter={onPanelEnter}
          onMouseLeave={onPanelLeave}
        >
          <div className="wrap">
            <div className="nav-mega-grid">
              {items.map((item) => {
                const linkPath = item.memberOnly && !user ? "/login" : item.path;
                return (
                  <Link
                    key={item.title}
                    to={linkPath}
                    className="nav-mega-item"
                    onClick={onNavigate}
                  >
                    <span className="nav-mega-icon">
                      <item.icon size={17} strokeWidth={1.5} />
                    </span>
                    <div className="nav-mega-text">
                      <div className="nav-mega-title">
                        {item.title}
                        {item.plus && <span className="nav-mega-plus">+</span>}
                      </div>
                      <div className="nav-mega-desc">{item.desc}</div>
                    </div>
                  </Link>
                );
              })}
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}