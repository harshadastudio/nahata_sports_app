import axios from 'axios';

const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:5050/api').replace(/\/$/, '');

export interface HeroSlide {
 id: number;
 title: string;
 titleHighlight?: string;
 subtitle?: string;
 description?: string;
 backgroundImage?: string;
 backgroundImages?: string[];
 button1Text?: string;
 button1Url?: string;
 button2Text?: string;
 button2Url?: string;
 stat1Value?: string;
 stat1Label?: string;
 stat2Value?: string;
 stat2Label?: string;
 stat3Value?: string;
 stat3Label?: string;
 featureCard1Title?: string;
 featureCard1Description?: string;
 featureCard1Badge?: string;
 featureCard2Title?: string;
 featureCard2Description?: string;
 displayOrder?: number;
 status?: string;
 showOnFrontend?: boolean;
}

export interface FrontendHeroSlidesResponse {
 success: boolean;
 message: string;
 data: HeroSlide[];
}

// Get active hero slides for frontend
export const getFrontendHeroSlides = async (): Promise<HeroSlide[]> => {
 try {
 const response = await axios.get<FrontendHeroSlidesResponse>(`${API_BASE_URL}/hero-slides/frontend`);
 return response.data.data;
 } catch (error) {
 console.error('Error fetching hero slides:', error);
 return [];
 }
};

