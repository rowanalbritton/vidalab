import { Toaster } from "@/components/ui/toaster"
import { QueryClientProvider } from '@tanstack/react-query'
import { queryClientInstance } from '@/lib/query-client'
import { BrowserRouter as Router, Route, Routes, Navigate } from 'react-router-dom';
import PageNotFound from './lib/PageNotFound';
import { AuthProvider } from '@/lib/AuthContext';
import ScrollToTop from './components/ScrollToTop';
import ProtectedRoute from '@/components/ProtectedRoute';
import Layout from '@/components/Layout';
import ErrorBoundary from '@/components/ErrorBoundary';
// Auth pages
import Login from '@/pages/Login';
import Register from '@/pages/Register';
import ForgotPassword from '@/pages/ForgotPassword';
import ResetPassword from '@/pages/ResetPassword';
// Public site pages
import Home from '@/pages/Home';
import About from '@/pages/About';
import AppLanding from '@/pages/AppLanding';
import VidaPlus from '@/pages/VidaPlus';
import Research from '@/pages/Research';
import ConditionDetail from '@/pages/ConditionDetail';
import Support from '@/pages/Support';
import RowansWork from '@/pages/RowansWork';
import Sasha from '@/pages/Sasha';
import Library from '@/pages/Library';
import DiseaseDetail from '@/pages/DiseaseDetail';
import Privacy from '@/pages/Privacy';
import Terms from '@/pages/Terms';
import Unsubscribe from '@/pages/Unsubscribe';
// Member app pages
import DailySignals from '@/pages/DailySignals';
import PatternMap from '@/pages/PatternMap';
import DoctorPrep from '@/pages/DoctorPrep';
import ThankYou from '@/pages/ThankYou';
import InstagramInsights from '@/pages/InstagramInsights';
import Trends from '@/pages/Trends';
import Welcome from '@/pages/Welcome';
import GettingStarted from '@/pages/GettingStarted';
import BodyWeather from '@/pages/BodyWeather';
import VidaDifferential from '@/pages/VidaDifferential';
import VidaExperiments from '@/pages/VidaExperiments';
import DoctorFinder from '@/pages/DoctorFinder';
import Health from '@/pages/Health';
import Community from '@/pages/Community';
import Favorites from '@/pages/Favorites';

const AuthenticatedApp = () => {
  return (
    <Routes>
      {/* Auth routes */}
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/reset-password" element={<ResetPassword />} />

      {/* Legacy redirects */}
      <Route path="/privacypolicy" element={<Navigate to="/privacy" replace />} />
      <Route path="/privacypolicy/*" element={<Navigate to="/privacy" replace />} />
      <Route path="/legal/privacy" element={<Navigate to="/privacy" replace />} />
      <Route path="/legal/terms" element={<Navigate to="/terms" replace />} />

      {/* Public site routes wrapped in Layout */}
      <Route element={<Layout />}>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
        <Route path="/app" element={<AppLanding />} />
        <Route path="/vida-plus" element={<VidaPlus />} />
        <Route path="/research" element={<Research />} />
        <Route path="/conditions/:slug" element={<ConditionDetail />} />
        <Route path="/support" element={<Support />} />
        <Route path="/rowans-work" element={<RowansWork />} />
        <Route path="/sasha" element={<Sasha />} />
        <Route path="/library" element={<Library />} />
        <Route path="/library/:slug" element={<DiseaseDetail />} />
        <Route path="/health" element={<Health />} />
        <Route path="/privacy" element={<Privacy />} />
        <Route path="/terms" element={<Terms />} />
        <Route path="/unsubscribe" element={<Unsubscribe />} />
        <Route path="/ThankYou" element={<ThankYou />} />
        <Route path="/getting-started" element={<GettingStarted />} />

        {/* Member-only routes */}
        <Route element={<ProtectedRoute unauthenticatedElement={<Navigate to="/login" replace />} />}>
          <Route path="/daily-signals" element={<DailySignals />} />
          <Route path="/pattern-map" element={<PatternMap />} />
          <Route path="/doctor-prep" element={<DoctorPrep />} />
          <Route path="/instagram-insights" element={<InstagramInsights />} />
          <Route path="/trends" element={<Trends />} />
          <Route path="/welcome" element={<Welcome />} />
          <Route path="/body-weather" element={<BodyWeather />} />
          <Route path="/vida-differential" element={<VidaDifferential />} />
          <Route path="/vida-experiments" element={<VidaExperiments />} />
          <Route path="/doctor-finder" element={<DoctorFinder />} />
          <Route path="/community" element={<Community />} />
          <Route path="/favorites" element={<Favorites />} />
        </Route>
      </Route>

      <Route path="*" element={<PageNotFound />} />
    </Routes>
  );
};

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <QueryClientProvider client={queryClientInstance}>
          <Router>
            <ScrollToTop />
            <AuthenticatedApp />
          </Router>
          <Toaster />
        </QueryClientProvider>
      </AuthProvider>
    </ErrorBoundary>
  )
}

export default App